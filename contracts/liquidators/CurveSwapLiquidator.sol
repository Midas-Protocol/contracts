// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../external/curve/ICurvePool.sol";

import { WETH } from "solmate/tokens/WETH.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title CurveSwapLiquidator
 * @notice Swaps seized token collateral via Curve as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract CurveSwapLiquidator is IRedemptionStrategy {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @notice Redeems custom collateral `token` for an underlying token.
   * @param inputToken The input wrapped token to be redeemed for an underlying token.
   * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
   * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
   * @return outputToken The underlying ERC20 token outputted.
   * @return outputAmount The quantity of underlying tokens outputted.
   */
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    // Exchange and store output
    (ICurvePool curvePool, int128 i, int128 j, address jToken, address payable wtoken) = abi.decode(
      strategyData,
      (ICurvePool, int128, int128, address, address)
    );
    outputToken = IERC20Upgradeable(jToken);
    inputToken.approve(address(curvePool), inputAmount);
    if (inputToken == curvePool) {
      curvePool.remove_liquidity_one_coin(curvePool.balanceOf(address(this)), j, 0);
      outputAmount = address(outputToken) == address(0) ? address(this).balance : outputToken.balanceOf(address(this));
    } else {
      outputAmount = curvePool.exchange(i, j, inputAmount, 0);
    }

    // Convert to W_NATIVE if ETH because `FuseSafeLiquidator.repayTokenFlashLoan` only supports tokens (not ETH) as output from redemptions (reverts on line 24 because `underlyingCollateral` is the zero address)
    if (address(outputToken) == address(0)) {
      WETH W_NATIVE = WETH(wtoken);
      W_NATIVE.deposit{ value: outputAmount }();
      return (IERC20Upgradeable(wtoken), outputAmount);
    }
  }
}
