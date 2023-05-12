// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ILiquidatorsRegistry {
  function hasRedemptionStrategyForTokens(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
  external
  view
  returns (bool);
  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
  external
  view
  returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData);

  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
  external
  view
  returns (IRedemptionStrategy strategy, bytes memory strategyData);
}