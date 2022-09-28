// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";

import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { IW_NATIVE } from "../../utils/IW_NATIVE.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface IAlpacaVault {
  /// @notice Return the total ERC20 entitled to the token holders. Be careful of unaccrued interests.
  function totalToken() external view returns (uint256);

  /// @notice Add more ERC20 to the bank. Hope to get some good returns.
  function deposit(uint256 amountToken) external payable;

  /// @notice Withdraw ERC20 from the bank by burning the share tokens.
  function withdraw(uint256 share) external;

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);
}

/**
 * @title Alpaca Finance ERC4626 Contract
 * @notice ERC4626 wrapper for Alpaca Finance Vaults
 * @author RedVeil
 *
 * Wraps https://github.com/alpaca-finance/bsc-alpaca-contract/blob/main/contracts/6/protocol/Vault.sol
 */
contract AlpacaERC4626 is MidasERC4626 {
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */

  IAlpacaVault public alpacaVault;
  IW_NATIVE wtoken;

  /* ========== INITIALIZER ========== */

  /**
     @notice Initializes the Vault.
     @param asset The ERC20 compliant token the Vault should accept.
     @param _alpacaVault The Alpaca Vault contract.
     @param _wtoken the wrapped native asset token contract address.
    */
  function initialize(
    ERC20Upgradeable asset,
    IAlpacaVault _alpacaVault,
    IW_NATIVE _wtoken
  ) public initializer {
    __MidasER4626_init(asset);

    performanceFee = 5e16;
    alpacaVault = _alpacaVault;
    wtoken = _wtoken;
    _asset().approve(address(alpacaVault), type(uint256).max);
  }

  function reinitialize() public reinitializer(2) onlyOwner {
    performanceFee = 5e16;
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return
      paused()
        ? wtoken.balanceOf(address(this))
        : alpacaVault.balanceOf(address(this)).mulDivDown(alpacaVault.totalToken(), alpacaVault.totalSupply());
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    alpacaVault.deposit(amount);
  }

  receive() external payable {
    wtoken.deposit{ value: msg.value }();
  }

  function convertToAlpacaVaultShares(uint256 shares) public returns (uint256) {
    uint256 supply = totalSupply();
    return supply == 0 ? shares : shares.mulDivUp(alpacaVault.balanceOf(address(this)), supply);
  }

  function beforeWithdraw(uint256, uint256 shares) internal override {
    alpacaVault.withdraw(convertToAlpacaVaultShares(shares));
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    alpacaVault.withdraw(alpacaVault.balanceOf(address(this)));
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    alpacaVault.deposit(_asset().balanceOf(address(this)));
  }
}
