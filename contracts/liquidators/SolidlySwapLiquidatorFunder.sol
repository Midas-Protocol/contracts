// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./SolidlySwapLiquidator.sol";
import "./IFundsConversionStrategy.sol";

contract SolidlySwapLiquidatorFunder is SolidlySwapLiquidator, IFundsConversionStrategy {
  function convert(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    return _convert(inputToken, inputAmount, strategyData);
  }

  function estimateInputAmount(uint256 outputAmount, bytes memory strategyData)
    external
    view
    returns (IERC20Upgradeable inputToken, uint256 inputAmount)
  {
    // Get Solidly router and path
    (IRouter solidlyRouter, address tokenTo, bool stable) = abi.decode(strategyData, (IRouter, address, bool));
  }
}
