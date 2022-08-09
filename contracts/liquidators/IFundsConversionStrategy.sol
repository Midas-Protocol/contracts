// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";

interface IFundsConversionStrategy is IRedemptionStrategy {
  function estimateInputAmount(uint256 outputAmount, bytes memory strategyData) external view returns (uint256 inputAmount);
}
