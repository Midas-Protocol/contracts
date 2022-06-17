// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MidasERC4626 } from "./MidasERC4626.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";

interface IBeefyVault {
  function want() external view returns (ERC20);

  function deposit(uint256 _amount) external;

  function withdraw(uint256 _shares) external;

  function withdrawAll() external;

  function balanceOf(address _account) external view returns (uint256);

  //Returns total balance of underlying token in the vault and its strategies
  function balance() external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function earn() external;

  function getPricePerFullShare() external view returns (uint256);
}

/**
 * @title Beefy ERC4626 Contract
 * @notice ERC4626 wrapper for beefy vaults
 * @author RedVeil
 *
 * Wraps https://github.com/beefyfinance/beefy-contracts/blob/master/contracts/BIFI/vaults/BeefyVaultV6.sol
 */
contract BeefyERC4626 is MidasERC4626 {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */

  IBeefyVault public immutable beefyVault;
  uint256 public immutable withdrawalFee;

  uint256 BPS_DENOMINATOR = 10_000;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _beefyVault The Beefy Vault contract.
     @param _withdrawalFee of the beefyVault in BPS
    */
  constructor(
    ERC20 _asset,
    IBeefyVault _beefyVault,
    uint256 _withdrawalFee
  )
    MidasERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol()))
    )
  {
    beefyVault = _beefyVault;
    withdrawalFee = _withdrawalFee;

    asset.approve(address(beefyVault), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return beefyVault.balanceOf(address(this)).mulDivUp(beefyVault.balance(), beefyVault.totalSupply());
  }

  /// @notice Calculates the total amount of underlying tokens the account holds.
  /// @return The total amount of underlying tokens the account holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    beefyVault.deposit(amount);
  }

  // takes as argument the internal ERC4626 shares to redeem
  // returns the external BeefyVault shares to withdraw
  function convertToBeefyVaultShares(uint256 shares) public returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? shares : shares.mulDivUp(beefyVault.balanceOf(address(this)), supply);
  }

  // takes as argument the internal ERC4626 shares to redeem
  function beforeWithdraw(uint256, uint256 shares) internal override {
    beefyVault.withdraw(convertToBeefyVaultShares(shares));
  }

  // returns the internal ERC4626 shares to withdraw
  function previewWithdraw(uint256 assets) public view override returns (uint256) {
    uint256 supply = totalSupply;

    uint256 assetsInBeefyVault = asset.balanceOf(address(beefyVault));
    if (assetsInBeefyVault < assets) {
      uint256 _withdraw = assets - assetsInBeefyVault;
      assets = assetsInBeefyVault + _withdraw.mulDivUp(BPS_DENOMINATOR, (BPS_DENOMINATOR - withdrawalFee));
    }

    return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
  }

  // takes as argument the internal ERC4626 shares to redeem
  function previewRedeem(uint256 shares) public view override returns (uint256) {
    uint256 supply = totalSupply;

    uint256 assets = convertToAssets(shares);

    uint256 assetsInBeefyVault = asset.balanceOf(address(beefyVault));
    if (assetsInBeefyVault < assets) {
      uint256 _withdraw = assets - assetsInBeefyVault;
      assets -= _withdraw.mulDivUp(withdrawalFee, BPS_DENOMINATOR);
    }

    return assets;
  }

  /* ========== EMERGENCY FUNCTIONS ========== */

  function emergencyWithdrawFromStrategyAndPauseContract() external override onlyOwner {
    beefyVault.withdraw(beefyVault.balanceOf(address(this)));
    _pause();
  }
}
