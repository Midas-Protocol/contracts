// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ILiquidatorsRegistryStorage {
  function redemptionStrategiesByName(string memory name) external view returns (IRedemptionStrategy);

  function redemptionStrategiesByTokens(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy);

  function defaultOutputToken(IERC20Upgradeable inputToken) external view returns (IERC20Upgradeable);
}

interface ILiquidatorsRegistryExtension {
  function getInputTokensByOutputToken(IERC20Upgradeable outputToken) external view returns (address[] memory);

  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData);

  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy strategy, bytes memory strategyData);

  function getAllRedemptionStrategies() external view returns (address[] memory);

  function swap(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IERC20Upgradeable outputToken
  ) external returns (uint256);

  function amountOutAndSlippageOfSwap(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IERC20Upgradeable outputToken
  ) external returns (uint256 outputAmount, uint256 slippage);

  function _setRedemptionStrategy(
    IRedemptionStrategy strategy,
    IERC20Upgradeable inputToken,
    IERC20Upgradeable outputToken
  ) external;

  function _setRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens
  ) external;

  function _resetRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens
  ) external;

  function _removeRedemptionStrategy(IRedemptionStrategy strategyToRemove) external;

  function _setDefaultOutputToken(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external;
}

interface ILiquidatorsRegistry is ILiquidatorsRegistryExtension, ILiquidatorsRegistryStorage {}
