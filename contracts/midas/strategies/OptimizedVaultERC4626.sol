// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./MidasERC4626.sol";
import "../vault/MultiAssetOptimizer.sol";

contract OptimizedVaultERC4626 is MidasERC4626 {
  constructor() {
    _disableInitializers();
  }

  MultiAssetOptimizer public vault;

  function initialize(ERC20Upgradeable _asset, MultiAssetOptimizer _vault) public initializer {
    __MidasER4626_init(_asset);

    performanceFee = 0;
    vault = _vault;
    _asset.approve(address(vault), type(uint256).max);
  }


  function totalAssets() public view override returns (uint256) {
    return _asset().balanceOf(address(this));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    vault.deposit(amount);
  }

  function beforeWithdraw(uint256, uint256 shares) internal override {
    vault.withdraw(convertToAssets(shares));
  }
}
