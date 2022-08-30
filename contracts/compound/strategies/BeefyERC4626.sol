// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IBeefyVault {
  function want() external view returns (ERC20Upgradeable);

  function deposit(uint256 _amount) external;

  function withdraw(uint256 _shares) external;

  function withdrawAll() external;

  function balanceOf(address _account) external view returns (uint256);

  //Returns total balance of underlying token in the vault and its strategies
  function balance() external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function earn() external;

  function getPricePerFullShare() external view returns (uint256);

  function strategy() external view returns (address);
}

/**
 * @title Beefy ERC4626 Contract
 * @notice ERC4626 wrapper for beefy vaults
 * @author RedVeil
 *
 * Wraps https://github.com/beefyfinance/beefy-contracts/blob/master/contracts/BIFI/vaults/BeefyVaultV6.sol
 */
contract BeefyERC4626 is MidasERC4626 {
  using SafeERC20Upgradeable for ERC20Upgradeable;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */

  IBeefyVault public beefyVault;
  uint256 public withdrawalFee;

  uint256 BPS_DENOMINATOR = 10_000;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param asset The ERC20 compliant token the Vault should accept.
     @param _beefyVault The Beefy Vault contract.
     @param _withdrawalFee of the beefyVault in BPS
    */
  function initialize(
    ERC20Upgradeable asset,
    IBeefyVault _beefyVault,
    uint256 _withdrawalFee
  ) public initializer {
    __MidasER4626_init(asset);
    beefyVault = _beefyVault;
    withdrawalFee = _withdrawalFee;

    asset.approve(address(beefyVault), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return
      paused()
        ? _asset().balanceOf(address(this))
        : beefyVault.balanceOf(address(this)).mulDivUp(beefyVault.balance(), beefyVault.totalSupply());
  }

  /// @notice Calculates the total amount of underlying tokens the account holds.
  /// @return The total amount of underlying tokens the account holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    beefyVault.deposit(amount);
  }

  // takes as argument the internal ERC4626 shares to redeem
  // returns the external BeefyVault shares to withdraw
  function convertToBeefyVaultShares(uint256 shares) public view returns (uint256) {
    uint256 supply = totalSupply();
    return supply == 0 ? shares : shares.mulDivUp(beefyVault.balanceOf(address(this)), supply);
  }

  // takes as argument the internal ERC4626 shares to redeem
  function beforeWithdraw(uint256, uint256 shares) internal override {
    beefyVault.withdraw(convertToBeefyVaultShares(shares));
  }

  // returns the internal ERC4626 shares to withdraw
  function previewWithdraw(uint256 assets) public view override returns (uint256) {
    uint256 supply = totalSupply();

    if (!paused()) {
      // calculate the possible withdrawal fee when not in emergency
      uint256 assetsInBeefyVault = _asset().balanceOf(address(beefyVault));
      if (assetsInBeefyVault < assets) {
        uint256 _withdraw = assets - assetsInBeefyVault;
        assets = assetsInBeefyVault + _withdraw.mulDivUp(BPS_DENOMINATOR, (BPS_DENOMINATOR - withdrawalFee));
      }
    }

    return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
  }

  // takes as argument the internal ERC4626 shares to redeem
  function previewRedeem(uint256 shares) public view override returns (uint256) {
    uint256 supply = totalSupply();

    if (!paused()) {
      // calculate the possible withdrawal fee when not in emergency
      uint256 assets = convertToAssets(shares);

      uint256 assetsInBeefyVault = _asset().balanceOf(address(beefyVault));
      if (assetsInBeefyVault < assets) {
        uint256 _withdraw = assets - assetsInBeefyVault;
        assets -= _withdraw.mulDivUp(withdrawalFee, BPS_DENOMINATOR);
      }

      return assets;
    } else {
      return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }
  }

  /* ========== EMERGENCY FUNCTIONS ========== */

  function emergencyWithdrawAndPause() external override onlyOwner {
    beefyVault.withdraw(beefyVault.balanceOf(address(this)));
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    beefyVault.deposit(_asset().balanceOf(address(this)));
  }
}
