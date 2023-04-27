// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";
import "../external/solidly/IRouter.sol";

contract SolidlySwapLiquidator is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    (IRouter _router, address _outputToken, bool _stable) = abi.decode(strategyData, (IRouter, address, bool));

    inputToken.approve(address(_router), inputAmount);
    _router.swapExactTokensForTokensSimple(
      inputAmount, //    uint amountIn,
      0, //    uint amountOutMin,
      address(inputToken), //    address tokenFrom,
      _outputToken, //    address tokenTo,
      _stable, //    bool stable,
      address(this), //    address to,
      block.timestamp //    uint deadline
    );

    outputToken = IERC20Upgradeable(_outputToken);
    outputAmount = outputToken.balanceOf(address(this));
  }
}