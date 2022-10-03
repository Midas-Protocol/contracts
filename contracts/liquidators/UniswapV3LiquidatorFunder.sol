// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { FixedPointMathLib } from "../utils/FixedPointMathLib.sol";
import { IFundsConversionStrategy } from "./IFundsConversionStrategy.sol";

import "../external/uniswap/ISwapRouter.sol";
import "../external/uniswap/Quoter/Quoter.sol";

contract UniswapV3LiquidatorFunder is IFundsConversionStrategy {
  using FixedPointMathLib for uint256;
  Quoter quoter;

  constructor(Quoter _quoter) {
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

  event log_address(address swapRouter);

  function _convert(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) internal returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    (, address _outputToken, uint24 fee, ISwapRouter swapRouter) = abi.decode(
      strategyData,
      (address, address, uint24, ISwapRouter)
    );
    outputToken = IERC20Upgradeable(_outputToken);

    inputToken.approve(address(swapRouter), inputAmount);

    ISwapRouter.ExactInputSingleParams memory params =
      ISwapRouter.ExactInputSingleParams(
          address(inputToken),
          _outputToken,
          fee,
          address(this),
          block.timestamp,
          inputAmount,
          0,
          0
      );
    
    outputAmount = swapRouter.exactInputSingle(params);
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
    (address _inputToken, address _outputToken, uint24 fee,) = abi.decode(
      strategyData,
      (address, address, uint24, ISwapRouter)
    );

    inputAmount = quoter.estimateMinSwapUniswapV3(_inputToken, _outputToken, outputAmount, fee);
    inputToken = IERC20Upgradeable(_inputToken);
  }
}