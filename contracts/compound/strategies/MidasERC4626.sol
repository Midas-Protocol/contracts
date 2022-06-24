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
  ) public override returns (uint256 shares) {
    shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }

    if (!paused()) {
      uint256 balanceBeforeWithdraw = asset.balanceOf(address(this));

      beforeWithdraw(assets, shares);

      assets = asset.balanceOf(address(this)) - balanceBeforeWithdraw;
    }

    _burn(owner, shares);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    asset.safeTransfer(receiver, assets);
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

    if (!paused()) {
      uint256 balanceBeforeWithdraw = asset.balanceOf(address(this));

      beforeWithdraw(assets, shares);

      assets = asset.balanceOf(address(this)) - balanceBeforeWithdraw;
    }

    _burn(owner, shares);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    asset.safeTransfer(receiver, assets);
  }

  // Should withdraw all funds from the strategy and pause the contract
  function emergencyWithdrawAndPause() external virtual onlyOwner {
    revert("!implementation");

    // Withdraw all assets from underlying strategy

    // _pause();
  }

  function unpause() external virtual onlyOwner {
    revert("!implementation");

    // _unpause();

    // Deposit all assets to underlying strategy
  }
}
