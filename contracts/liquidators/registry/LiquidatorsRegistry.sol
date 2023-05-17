// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../IRedemptionStrategy.sol";
import "../../midas/DiamondExtension.sol";
import "./LiquidatorsRegistryStorage.sol";
import { IRouter } from "../../external/solidly/IRouter.sol";
import { IPair } from "../../external/solidly/IPair.sol";
import { IUniswapV2Pair } from "../../external/uniswap/IUniswapV2Pair.sol";

import { CurveLpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import { CurveV2LpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveV2LpTokenPriceOracleNoRegistry.sol";
import { SaddleLpPriceOracle } from "../../oracles/default/SaddleLpPriceOracle.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "./ILiquidatorsRegistry.sol";

contract LiquidatorsRegistry is LiquidatorsRegistryStorage, DiamondBase {
  constructor(AddressesProvider _ap) SafeOwnable() {
    ap = _ap;
  }

  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace)
    public
    override
    onlyOwner
  {
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }

  function _setRedemptionStrategy(
    IRedemptionStrategy strategy,
    IERC20Upgradeable inputToken,
    IERC20Upgradeable outputToken
  ) public onlyOwner {
    IRedemptionStrategy oldStrategy = redemptionStrategiesByName[strategy.name()];

    redemptionStrategiesByTokens[inputToken][outputToken] = strategy;
    redemptionStrategiesByName[strategy.name()] = strategy;

    redemptionStrategies.remove(address(oldStrategy));
    redemptionStrategies.add(address(strategy));
  }

  function _setRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens
  ) public onlyOwner {
    require(strategies.length == inputTokens.length && inputTokens.length == outputTokens.length, "!arrays len");

    for (uint256 i = 0; i < strategies.length; i++) {
      IRedemptionStrategy oldStrategy = redemptionStrategiesByName[strategies[i].name()];

      redemptionStrategiesByTokens[inputTokens[i]][outputTokens[i]] = strategies[i];
      redemptionStrategiesByName[strategies[i].name()] = strategies[i];

      redemptionStrategies.remove(address(oldStrategy));
      redemptionStrategies.add(address(strategy));
    }
  }
}
