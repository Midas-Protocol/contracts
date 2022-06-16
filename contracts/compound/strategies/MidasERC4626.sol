// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "solmate/mixins/ERC4626.sol";
import "solmate/tokens/ERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

abstract contract MidasERC4626 is ERC4626, Ownable {
  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol
  ) ERC4626(_asset, _name, _symbol) {}

  function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
    revert("previewWithdraw must be overridden");
  }

  function previewRedeem(uint256 shares) public view virtual returns (uint256) {
    revert("previewRedeem must be overridden");
  }

  function previewMint(uint256 shares) public view virtual returns (uint256) {
    revert("previewMint must be overridden");
  }

  function previewDeposit(uint256 assets) public view virtual returns (uint256) {
    revert("previewDeposit must be overridden");
  }
}
