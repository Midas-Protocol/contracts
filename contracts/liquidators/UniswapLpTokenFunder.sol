//// SPDX-License-Identifier: UNLICENSED
//pragma solidity >=0.8.0;
//
//import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
//
//import { IFundsConversionStrategy } from "./IFundsConversionStrategy.sol";
//import { IUniswapV2Pair } from "../external/uniswap/IUniswapV2Pair.sol";
//import { IUniswapV2Router01 } from "../external/uniswap/IUniswapV2Router01.sol";
//
//contract UniswapLpTokenLiquidatorFunder is IFundsConversionStrategy {
//    function convert(
//        IERC20Upgradeable inputToken,
//        uint256 inputAmount,
//        bytes memory strategyData
//    ) external returns (IERC20Upgradeable, uint256) {
//        if (address(inputToken) == address(0)) {
//            // mint LP tokens
//
//            (address inputTokenAddress, address router, IUniswapV2Pair pair) = abi.decode(
//                strategyData,
//                (address, address)
//            );
//
//            pair.mint(address(this));
//
//            address token0 = pair.token0();
//            address token1 = pair.token1();
//
////            uint256 wethRequired = getAmountsIn(
////                uniswapV2RouterForBorrow.factory(),
////                flashSwapReturnAmount,
////                array(W_NATIVE_ADDRESS, fundingTokenAddress)
////            )[0];
//
//            address otherTokenAddress = (inputTokenAddress == token0) ? token1 : token0;
//
//            uint256 otherTokenAmount = getAmountsIn(
//                IUniswapV2Router01(router).factory(),
//                inputAmount / 2,
//                array(inputTokenAddress, otherTokenAddress)
//            );
//
//            IUniswapV2Router01(router).swapExactTokensForTokens(
//                otherTokenAmount,
//                inputAmount / 2,
//                array(inputTokenAddress, otherTokenAddress),
//                address(this),
//                block.timestamp
//            );
//
//            IUniswapV2Router01(router).addLiquidity(
//                token0,
//                token1,
//                otherTokenAmount,
//                inputAmount / 2,
//                otherTokenAmount * 97 / 100,
//                inputAmount * 97 / 200,
//                address(this),
//                block.timestamp
//            );
//
//            return (IERC20Upgradeable(address(pair)), liquidity);
//        } else {
//            return redeem(inputToken, inputAmount, strategyData);
//        }
//    }
//
//    function estimateInputAmount(uint256 outputAmount, bytes memory strategyData)
//    external
//    view
//    returns (uint256 inputAmount) {
//
//    }
//
//   /**
//    * @dev Fetches and sorts the reserves for a pair.
//    * Original code from PancakeLibrary.
//    */
//    function getReserves(
//        address factory,
//        address tokenA,
//        address tokenB
//    ) private view returns (uint256 reserveA, uint256 reserveB) {
//        (address token0, ) = PancakeLibrary.sortTokens(tokenA, tokenB);
//        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(IUniswapV2Factory(factory).getPair(tokenA, tokenB))
//        .getReserves();
//        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
//    }
//
//   /**
//    * @dev Performs chained getAmountIn calculations on any number of pairs.
//    * Original code from PancakeLibrary.
//    */
//    function getAmountsIn(
//        address factory,
//        uint256 amountOut,
//        address[] memory path
//    ) private view returns (uint256[] memory amounts) {
//        require(path.length >= 2, "PancakeLibrary: INVALID_PATH");
//        amounts = new uint256[](path.length);
//        amounts[amounts.length - 1] = amountOut;
//        for (uint256 i = path.length - 1; i > 0; i--) {
//            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i - 1], path[i]);
//            amounts[i - 1] = PancakeLibrary.getAmountIn(amounts[i], reserveIn, reserveOut);
//        }
//    }
//}