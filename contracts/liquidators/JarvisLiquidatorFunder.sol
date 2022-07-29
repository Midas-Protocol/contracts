// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IFundsConversionStrategy.sol";
import "./JarvisSynthereumLiquidator.sol";
import { FixedPointMathLib } from "../utils/FixedPointMathLib.sol";

contract JarvisLiquidatorFunder is IFundsConversionStrategy, JarvisSynthereumLiquidator {
    using FixedPointMathLib for uint256;
    uint256 private immutable ONE = 1e18;

    constructor(ISynthereumLiquidityPool _pool, uint64 _txExpirationPeriod) JarvisSynthereumLiquidator(_pool, _txExpirationPeriod) {
    }

    function estimateInputAmount(uint256 outputAmount) external returns (uint256 inputAmount) {
        // synthTokensReceived / ONE = outputAmount / inputAmount
        // => inputAmount = (ONE * outputAmount) / synthTokensReceived
        (uint256 synthTokensReceived, ) = pool.getMintTradeInfo(ONE);
        inputAmount = ONE.mulDivUp(outputAmount, synthTokensReceived);
    }
}
