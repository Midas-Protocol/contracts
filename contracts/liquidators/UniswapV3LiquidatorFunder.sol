// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { FixedPointMathLib } from "../utils/FixedPointMathLib.sol";
import { IFundsConversionStrategy } from "./IFundsConversionStrategy.sol";

import "../external/uniswap/ISwapRouter.sol";
import "../external/uniswap/IUniswapV3Factory.sol";
import "../external/uniswap/IQuoterV2.sol";

contract UniswapV3Liquidator is IFundsConversionStrategy {
  using FixedPointMathLib for uint256;
  ISwapRouter swapRouter;
  IUniswapV3Factory factory;
  IQuoterV2 quoter;

  constructor(ISwapRouter _router, IUniswapV3Factory _factory, IQuoterV2 _quoter) {
    swapRouter = _router;
    factory = _factory;
    quoter = _quoter;
  }

  /**
   * @dev Redeems `inputToken` for `outputToken` where `inputAmount` < `outputAmount`
   * @param inputToken Address of the token
   * @param inputAmount input amount
   * @param strategyData context specific data like input token, pool address and tx expiratio period
   */
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    return _convert(inputToken, inputAmount, strategyData);
  }

  function convert(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    return _convert(inputToken, inputAmount, strategyData);
  }

  function _convert(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) internal returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    // (address _outputToken, uint24 fee) = abi.decode(
    //   strategyData,
    //   (address, uint24)
    // );
    // outputToken = IERC20Upgradeable(_outputToken);

    // ISwapRouter.ExactInputSingleParams memory params =
    //   ISwapRouter.ExactInputSingleParams({
    //       tokenIn: address(inputToken),
    //       tokenOut: _outputToken,
    //       fee: fee,
    //       recipient: address(this),
    //       deadline: block.timestamp,
    //       amountIn: inputAmount,
    //       amountOutMinimum: 0,
    //       sqrtPriceLimitX96: 0
    //   });
    
    // outputAmount = swapRouter.exactInputSingle(params);
  }

  /**
   * @dev Estimates the needed input amount of the input token for the conversion to return the desired output amount.
   * @param outputAmount the desired output amount
   * @param strategyData the input token
   */
  function estimateInputAmount(uint256 outputAmount, bytes memory strategyData)
    external
    view
    returns (IERC20Upgradeable inputToken, uint256 inputAmount)
  {
    // (address _inputToken, address _outputToken, uint24 fee, uint256 amountInMaximum) = abi.decode(
    //   strategyData,
    //   (address, address, uint24)
    // );

    // IQuoterV2.QuoteExactOutputSingleParams memory params = 
    //   IQuoterV2.QuoteExactOutputSingleParams({
    //     tokenIn: _inputToken,
    //     tokenOut: _outputToken,
    //     amount: outputAmount,
    //     fee: fee,
    //     sqrtPriceLimitX96: 0
    //   });
    
    // (inputAmount, , , ) = quoter.quoteExactOutputSingle(params);
    // inputToken = IERC20Upgradeable(_inputToken);
  }
}