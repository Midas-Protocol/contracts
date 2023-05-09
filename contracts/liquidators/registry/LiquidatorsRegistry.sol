// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../IRedemptionStrategy.sol";
import "../../midas/DiamondExtension.sol";
import "./LiquidatorsRegistryStorage.sol";
import { IRouter } from "../../external/solidly/IRouter.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LiquidatorsRegistry is LiquidatorsRegistryStorage, DiamondBase {
  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) public override {
    require(msg.sender == owner(), "!unauthorized - no admin rights");
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }

  function hasRedemptionStrategyForTokens(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    public
    view
    returns (bool)
  {
    IRedemptionStrategy strategy = redemptionStrategiesByTokens[inputToken][outputToken];
    return address(strategy) != address(0);
  }

  function _setRedemptionStrategy(
    IRedemptionStrategy strategy,
    IERC20Upgradeable inputToken,
    IERC20Upgradeable outputToken
  ) public onlyOwner {
    redemptionStrategiesByTokens[inputToken][outputToken] = strategy;
    redemptionStrategiesByName[strategy.name()] = strategy;
  }

  function _setRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens
  ) public onlyOwner {
    require(strategies.length == inputTokens.length && inputTokens.length == outputTokens.length, "!arrays len");

    for (uint256 i = 0; i < strategies.length; i++) {
      redemptionStrategiesByTokens[inputTokens[i]][outputTokens[i]] = strategies[i];
      redemptionStrategiesByName[strategies[i].name()] = strategies[i];
    }
  }

  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy strategy, bytes memory strategyData)
  {
    strategy = redemptionStrategiesByTokens[inputToken][outputToken];

    if (address(strategy) == address(redemptionStrategiesByName["SolidlySwapLiquidator"])) {
      strategyData = solidlySwapLiquidatorData(inputToken, outputToken);
    }
  }

  function solidlySwapLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    // assuming bsc for the chain
    IRouter solidlyRouter = IRouter(0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109);
    address tokenTo = address(outputToken);

    // Check if stable pair exists
    address volatilePair = solidlyRouter.pairFor(address(inputToken), tokenTo, false);
    address stablePair = solidlyRouter.pairFor(address(inputToken), tokenTo, true);

    require(
      solidlyRouter.isPair(stablePair) || solidlyRouter.isPair(volatilePair),
      "Invalid SolidlyLiquidator swap path."
    );

    bool stable;
    if (!solidlyRouter.isPair(stablePair)) {
      stable = false;
    } else if (!solidlyRouter.isPair(volatilePair)) {
      stable = true;
    } else {
      (uint256 stableR0, uint256 stableR1) = solidlyRouter.getReserves(address(inputToken), tokenTo, true);
      (uint256 volatileR0, uint256 volatileR1) = solidlyRouter.getReserves(address(inputToken), tokenTo, false);
      // Determine which swap has higher liquidity
      if (stableR0 > volatileR0 && stableR1 > volatileR1) {
        stable = true;
      } else {
        stable = false;
      }
    }

    strategyData = abi.encode(solidlyRouter, outputToken, stable);
  }
}
