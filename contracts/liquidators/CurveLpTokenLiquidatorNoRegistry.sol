// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "../external/curve/ICurvePool.sol";
import "../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";

import { WETH } from "solmate/tokens/WETH.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title CurveLpTokenLiquidator
 * @notice Redeems seized Curve LP token collateral for underlying tokens for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract CurveLpTokenLiquidatorNoRegistry is IRedemptionStrategy {
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
    (uint8 curveCoinIndex, address underlying, address payable wtoken, address _oracle) = abi.decode(
      strategyData,
      (uint8, address, address, address)
    );
    // the oracle contains the pool registry
    CurveLpTokenPriceOracleNoRegistry oracle = CurveLpTokenPriceOracleNoRegistry(_oracle);
    // Remove liquidity from Curve pool in the form of one coin only (and store output as new collateral)
    ICurvePool curvePool = ICurvePool(oracle.poolOf(address(inputToken)));
    curvePool.remove_liquidity_one_coin(inputAmount, int128(int8(curveCoinIndex)), 1);

    if (underlying == address(0) || underlying == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      WETH(wtoken).deposit{ value: address(this).balance }();
      outputToken = IERC20Upgradeable(wtoken);
    } else {
      outputToken = IERC20Upgradeable(underlying);
    }
    outputAmount = outputToken.balanceOf(address(this));

    return (outputToken, outputAmount);
  }
}
