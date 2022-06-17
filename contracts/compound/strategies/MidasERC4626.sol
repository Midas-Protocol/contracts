// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "solmate/mixins/ERC4626.sol";
import "solmate/tokens/ERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

abstract contract MidasERC4626 is ERC4626, Ownable {
  using SafeTransferLib for ERC20;

  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol
  ) ERC4626(_asset, _name, _symbol) {}

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

    uint256 balanceBeforeWithdraw = asset.balanceOf(address(this));

    beforeWithdraw(assets, shares);

    _burn(owner, shares);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    asset.safeTransfer(receiver, asset.balanceOf(address(this)) - balanceBeforeWithdraw);
  }

  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public override returns (uint256 assets) {
    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }

    // Check for rounding error since we round down in previewRedeem.
    require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

    uint256 balanceBeforeWithdraw = asset.balanceOf(address(this));

    beforeWithdraw(assets, shares);

    _burn(owner, shares);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    asset.safeTransfer(receiver, asset.balanceOf(address(this)) - balanceBeforeWithdraw);
  }
}
