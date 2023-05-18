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
import "./LiquidatorsRegistryExtension.sol";

contract LiquidatorsRegistry is LiquidatorsRegistryStorage, DiamondBase {
  using EnumerableSet for EnumerableSet.AddressSet;

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

  function asExtension() public view returns (LiquidatorsRegistryExtension) {
    return LiquidatorsRegistryExtension(address(this));
  }
}
