// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { ERC4626 } from "solmate/mixins/ERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { IW_NATIVE } from "../../utils/IW_NATIVE.sol";

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
contract AlpacaERC4626 is ERC4626 {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */

  IAlpacaVault public immutable alpacaVault;
  IW_NATIVE wtoken;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _alpacaVault The Alpaca Vault contract.
     @param _wtoken the wrapped native asset token contract address.
    */
  constructor(
    ERC20 _asset,
    IAlpacaVault _alpacaVault,
    IW_NATIVE _wtoken
  )
    ERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol()))
    )
  {
    alpacaVault = _alpacaVault;
    wtoken = _wtoken;
    asset.approve(address(alpacaVault), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return alpacaVault.balanceOf(address(this)).mulDivDown(alpacaVault.totalToken(), alpacaVault.totalSupply());
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    alpacaVault.deposit(amount);
  }

  receive() external payable {
    wtoken.deposit{ value: msg.value }();
  }

  function beforeWithdraw(uint256, uint256 shares) internal override {
    alpacaVault.withdraw(shares);
  }
}
