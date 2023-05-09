// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../midas/SafeOwnableUpgradeable.sol";
import "../IRedemptionStrategy.sol";
import { IRouter } from "../../external/solidly/IRouter.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LiquidatorsRegistry is SafeOwnableUpgradeable {
  mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => bytes32)) public redemptionStrategiesByTokens;
  mapping(bytes32 => IRedemptionStrategy) public redemptionStrategiesByID;

  constructor() {
    _disableInitializers();
  }

  function initialize() public initializer {
    __SafeOwnable_init(msg.sender);
  }

  function hasRedemptionStrategyForTokens(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    public
    view
    returns (bool)
  {
    bytes32 strategyId = redemptionStrategiesByTokens[inputToken][outputToken];
    return strategyId != bytes32(0);
  }

  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy strategy, bytes memory strategyData)
  {
    bytes32 strategyId = redemptionStrategiesByTokens[inputToken][outputToken];
    strategy = redemptionStrategiesByID[strategyId];
    if (strategyId == keccak256(bytes("SolidlySwapLiquidator"))) {
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

  function _addRedemptionStrategy(
    IRedemptionStrategy strategy,
    IERC20Upgradeable inputToken,
    IERC20Upgradeable outputToken
  ) public onlyOwner {
    bytes32 id = keccak256(bytes(strategy.name()));
    redemptionStrategiesByTokens[inputToken][outputToken] = id;
    redemptionStrategiesByID[id] = strategy;
  }

  function _addRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens
  ) public onlyOwner {
    require(strategies.length == inputTokens.length && inputTokens.length == outputTokens.length, "!arrays len");

    for (uint256 i = 0; i < strategies.length; i++) {
      bytes32 id = keccak256(bytes(strategies[i].name()));
      redemptionStrategiesByTokens[inputTokens[i]][outputTokens[i]] = id;
      redemptionStrategiesByID[id] = strategies[i];
    }
  }
}
