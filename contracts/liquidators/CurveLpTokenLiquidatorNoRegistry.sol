// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "../external/curve/ICurvePool.sol";
import "../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";

import {WETH} from "solmate/tokens/WETH.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title CurveLpTokenLiquidator
 * @notice Redeems seized Curve LP token collateral for underlying tokens for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract CurveLpTokenLiquidatorNoRegistry is IRedemptionStrategy {
    /**
     * @dev W_NATIVE contract object.
     */
    WETH public immutable W_NATIVE;
    CurveLpTokenPriceOracleNoRegistry public immutable oracle; // oracle contains registry

    constructor(WETH wnative, CurveLpTokenPriceOracleNoRegistry _oracle) {
        W_NATIVE = wnative;
        oracle = _oracle;
    }

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
    )
        external
        override
        returns (IERC20Upgradeable outputToken, uint256 outputAmount)
    {
        (uint8 curveCoinIndex, address underlying) = abi.decode(
            strategyData,
            (uint8, address)
        );

        // Remove liquidity from Curve pool in the form of one coin only (and store output as new collateral)
        ICurvePool curvePool = ICurvePool(oracle.poolOf(address(inputToken)));
        curvePool.remove_liquidity_one_coin(
            inputAmount,
            int128(int8(curveCoinIndex)),
            1
        );
        outputToken = IERC20Upgradeable(
            underlying == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                ? address(0)
                : underlying
        );
        outputAmount = address(outputToken) == address(0)
            ? address(this).balance
            : outputToken.balanceOf(address(this));

        // Convert to W_NATIVE if ETH because `FuseSafeLiquidator.repayTokenFlashLoan` only supports tokens (not ETH) as output from redemptions (reverts on line 24 because `underlyingCollateral` is the zero address)
        if (address(outputToken) == address(0)) {
            W_NATIVE.deposit{value: outputAmount}();
            return (IERC20Upgradeable(address(W_NATIVE)), outputAmount);
        }
    }
}
