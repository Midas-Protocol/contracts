// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "solmate/mixins/ERC4626.sol";
import "solmate/tokens/ERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";

abstract contract MidasERC4626 is ERC4626, Ownable, Pausable {
  using FixedPointMathLib for uint256;
  using SafeTransferLib for ERC20;

  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol
  ) ERC4626(_asset, _name, _symbol) {}

  function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256 shares) {
    // Check for rounding error since we round down in previewDeposit.
    require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

    // Need to transfer before minting or ERC777s could reenter.
    asset.safeTransferFrom(msg.sender, address(this), assets);

    _mint(receiver, shares);

    emit Deposit(msg.sender, receiver, assets, shares);

    afterDeposit(assets, shares);
  }

  function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256 assets) {
    assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

    // Need to transfer before minting or ERC777s could reenter.
    asset.safeTransferFrom(msg.sender, address(this), assets);

    _mint(receiver, shares);

    emit Deposit(msg.sender, receiver, assets, shares);

    afterDeposit(assets, shares);
  }

  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override whenNotPaused returns (uint256 shares) {
    shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }

    uint256 balanceBeforeWithdraw = asset.balanceOf(address(this));

    beforeWithdraw(assets, shares);

    _burn(owner, shares);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    asset.safeTransfer(receiver, asset.balanceOf(address(this)) - balanceBeforeWithdraw);
  }

  function emergencyRedeem(uint256 shares) external returns (uint256) {
    return redeem(shares, msg.sender, msg.sender);
  }

  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public override returns (uint256 assets) {
    uint256 supply = totalSupply;
    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }

    // Check for rounding error since we round down in previewRedeem.
    require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

    uint256 assetsToTransfer;
    if (!paused()) {
      uint256 balanceBeforeWithdraw = asset.balanceOf(address(this));
      beforeWithdraw(assets, shares);
      assetsToTransfer = asset.balanceOf(address(this)) - balanceBeforeWithdraw;
    } else {
      assetsToTransfer = supply == 0 ? shares : shares.mulDivUp(asset.balanceOf(address(this)), supply);
    }

    _burn(owner, shares);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    asset.safeTransfer(receiver, assetsToTransfer);

    // TODO return assets or assetsToTransfer ?
  }

  // Should withdraw all funds from the strategy and pause the contract
  function emergencyWithdrawAndPause() external virtual onlyOwner {
    beforeWithdraw(totalAssets(), totalSupply);
    _pause();
  }

  function unpause() external virtual onlyOwner {
    _unpause();
    afterDeposit(asset.balanceOf(address(this)), totalSupply);
  }
}
