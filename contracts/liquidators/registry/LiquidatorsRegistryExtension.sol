// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./ILiquidatorsRegistry.sol";
import "./LiquidatorsRegistryStorage.sol";

import "../IRedemptionStrategy.sol";
import "../../midas/DiamondExtension.sol";

import { IRouter } from "../../external/solidly/IRouter.sol";
import { IPair } from "../../external/solidly/IPair.sol";
import { IUniswapV2Pair } from "../../external/uniswap/IUniswapV2Pair.sol";

import { CurveLpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import { CurveV2LpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveV2LpTokenPriceOracleNoRegistry.sol";
import { SaddleLpPriceOracle } from "../../oracles/default/SaddleLpPriceOracle.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { XBombSwap } from "../XBombLiquidatorFunder.sol";

contract LiquidatorsRegistryExtension is LiquidatorsRegistryStorage, DiamondExtension, ILiquidatorsRegistry {
  function _getExtensionFunctions() external pure override returns (bytes4[] memory) {
    uint8 fnsCount = 3;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.getRedemptionStrategies.selector;
    functionSelectors[--fnsCount] = this.getRedemptionStrategy.selector;
    functionSelectors[--fnsCount] = this.hasRedemptionStrategyForTokens.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }

  function hasRedemptionStrategyForTokens(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    public
    view
    returns (bool)
  {
    IRedemptionStrategy strategy = redemptionStrategiesByTokens[inputToken][outputToken];
    return address(strategy) != address(0);
  }

  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData)
  {
    /*
  if (expectedOutputToken) {
    let tokenToRedeem = inputToken;
    // chain redemptions as long as it is redeemable and is not the needed output token
    while (tokenToRedeem != expectedOutputToken && tokenToRedeem in fuse.redemptionStrategies) {
      const { strategyAddress, strategyData, outputToken } = (await getStrategyAndData(
        fuse,
        tokenToRedeem
      )) as StrategyAndData;

      // avoid going in an endless loop
      // it is not mission critical to reach the expected output token,
      // so just break instead of throwing
      if (tokenPath.find((p) => p == outputToken)) break;

      tokenPath.push(outputToken);
      strategies.push(strategyAddress);
      datas.push(strategyData);

      tokenToRedeem = outputToken;
    }
  }
    */


    strategies = new IRedemptionStrategy[](1);
    strategiesData = new bytes[](1);

    (strategies[0], strategiesData[0]) = getRedemptionStrategy(inputToken, outputToken);
  }

  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    public
    view
    returns (IRedemptionStrategy strategy, bytes memory strategyData)
  {
    strategy = redemptionStrategiesByTokens[inputToken][outputToken];

    if (isStrategy(strategy, "SolidlySwapLiquidator")) {
      strategyData = solidlySwapLiquidatorData(inputToken, outputToken);
    } else if (isStrategy(strategy, "SolidlyLpTokenLiquidator")) {
      strategyData = solidlyLpTokenLiquidatorData(inputToken, outputToken);
    } else if (isStrategy(strategy, "UniswapV2LiquidatorFunder")) {
      strategyData = uniswapV2LiquidatorData(inputToken, outputToken);
    } else if (isStrategy(strategy, "AlgebraSwapLiquidator")) {
      strategyData = algebraSwapLiquidatorData(inputToken, outputToken);
    } else if (isStrategy(strategy, "BalancerSwapLiquidator") || isStrategy(strategy, "BalancerLpTokenLiquidator")) {
      strategyData = balancerLiquidatorData(inputToken, outputToken);
    } else if (isStrategy(strategy, "UniswapLpTokenLiquidator") || isStrategy(strategy, "GelatoGUniLiquidator")) {
      strategyData = uniswapLpTokenLiquidatorData(inputToken, outputToken);
    } else if (isStrategy(strategy, "SaddleLpTokenLiquidator")) {
      strategyData = saddleLpTokenLiquidatorData(inputToken, outputToken);
    } else if (isStrategy(strategy, "CurveLpTokenLiquidatorNoRegistry")) {
      strategyData = curveLpTokenLiquidatorNoRegistryData(inputToken, outputToken);
    } else if (isStrategy(strategy, "CurveSwapLiquidator")) {
      strategyData = curveSwapLiquidatorData(inputToken, outputToken);
    } else if (isStrategy(strategy, "JarvisLiquidatorFunder")) {
      strategyData = jarvisLiquidatorFunderData(inputToken, outputToken);
    } else if (isStrategy(strategy, "XBombLiquidatorFunder")) {
      strategyData = xBombLiquidatorData(inputToken, outputToken);
      //} else if (isStrategy(strategy, "ERC4626Liquidator")) {
      //   TODO strategyData = erc4626LiquidatorData(inputToken, outputToken);
    }
  }

  function isStrategy(IRedemptionStrategy strategy, string memory name) internal view returns (bool) {
    return address(strategy) == address(redemptionStrategiesByName[name]);
  }

  function pickPreferredToken(address[] memory tokens, address strategyOutputToken) internal view returns (address) {
    address wnative = ap.getAddress("wtoken");
    address stableToken = ap.getAddress("stableToken");
    address wbtc = ap.getAddress("wBTCToken");

    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == strategyOutputToken) return strategyOutputToken;
    }
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == wnative) return wnative;
    }
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == stableToken) return stableToken;
    }
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == wbtc) return wbtc;
    }
    return tokens[0];
  }

  function getUniswapV2Router(IERC20Upgradeable inputToken) internal view returns (address) {
    // get asset specific router or default
    return ap.getAddress("IUniswapV2Router02");
  }

  function solidlySwapLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    // assuming bsc for the chain
    IRouter solidlyRouter = IRouter(ap.getAddress("chainConfig.chainAddresses.SOLIDLY_SWAP_ROUTER"));
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

  function solidlyLpTokenLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    IPair lpToken = IPair(address(inputToken));
    require(
      address(outputToken) == lpToken.token0() || address(outputToken) == lpToken.token1(),
      "Output token does not match either of the pair tokens!"
    );

    strategyData = abi.encode(ap.getAddress("chainConfig.chainAddresses.SOLIDLY_SWAP_ROUTER"), outputToken);
  }

  function balancerLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    strategyData = abi.encode(outputToken);
  }

  function uniswapV2LiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    IERC20Upgradeable[] memory swapPath = new IERC20Upgradeable[](2);
    swapPath[0] = inputToken;
    swapPath[1] = outputToken;
    strategyData = abi.encode(getUniswapV2Router(inputToken), swapPath);
  }

  function algebraSwapLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    strategyData = abi.encode(outputToken, ap.getAddress("chainConfig.chainAddresses.ALGEBRA_SWAP_ROUTER"));
  }

  function uniswapLpTokenLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    IUniswapV2Pair lpToken = IUniswapV2Pair(address(inputToken));
    address token0 = lpToken.token0();
    address token1 = lpToken.token1();
    bool token0IsOutputToken = address(outputToken) == lpToken.token0();
    bool token1IsOutputToken = address(outputToken) == lpToken.token1();
    require(token0IsOutputToken || token1IsOutputToken, "Output token does not match either of the pair tokens!");

    address[] memory swapPath = new address[](2);
    swapPath[0] = token0IsOutputToken ? token1 : token0;
    swapPath[1] = token1IsOutputToken ? token0 : token1;
    address[] memory emptyPath = new address[](0);

    strategyData = abi.encode(
      getUniswapV2Router(inputToken),
      token0IsOutputToken ? emptyPath : swapPath,
      token1IsOutputToken ? emptyPath : swapPath
    );
  }

  function saddleLpTokenLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    SaddleLpPriceOracle saddleLpPriceOracle = SaddleLpPriceOracle(ap.getAddress("SaddleLpPriceOracle"));
    address[] memory tokens = saddleLpPriceOracle.getUnderlyingTokens(address(inputToken));

    address wnative = ap.getAddress("wtoken");
    address preferredToken = pickPreferredToken(tokens, address(outputToken));
    address actualOutputToken = preferredToken;
    if (preferredToken == address(0) || preferredToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      actualOutputToken = wnative;
    }
    // TODO outputToken = actualOutputToken

    strategyData = abi.encode(preferredToken, saddleLpPriceOracle, wnative);
  }

  function curveLpTokenLiquidatorNoRegistryData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    CurveLpTokenPriceOracleNoRegistry curveLpOracle = CurveLpTokenPriceOracleNoRegistry(
      ap.getAddress("CurveLpTokenPriceOracleNoRegistry")
    );
    address[] memory tokens = curveLpOracle.getUnderlyingTokens(address(inputToken));

    address wnative = ap.getAddress("wtoken");
    address preferredToken = pickPreferredToken(tokens, address(outputToken));
    address actualOutputToken = preferredToken;
    if (preferredToken == address(0) || preferredToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      actualOutputToken = wnative;
    }
    // TODO outputToken = actualOutputToken

    strategyData = abi.encode(preferredToken, wnative, curveLpOracle);
  }

  function curveSwapLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    address curveV1Oracle = ap.getAddress("CurveLpTokenPriceOracleNoRegistry");
    address curveV2Oracle = ap.getAddress("CurveV2LpTokenPriceOracleNoRegistry");
    address wnative = ap.getAddress("wtoken");

    strategyData = abi.encode(curveV1Oracle, curveV2Oracle, inputToken, outputToken, wnative);
  }

  function jarvisLiquidatorFunderData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    AddressesProvider.JarvisPool[] memory pools = ap.getJarvisPools();
    for (uint256 i = 0; i < pools.length; i++) {
      AddressesProvider.JarvisPool memory pool = pools[i];
      if (pool.syntheticToken == address(inputToken)) {
        strategyData = abi.encode(pool.syntheticToken, pool.liquidityPool, pool.expirationTime);
        //outputToken = pool.collateralToken;
        break;
      } else if (pool.collateralToken == address(inputToken)) {
        strategyData = abi.encode(pool.collateralToken, pool.liquidityPool, pool.expirationTime);
      }
    }
  }

  // TODO remove after testing
  function xBombLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    if (block.chainid == 97) {
      IERC20Upgradeable chapelBomb = IERC20Upgradeable(0xe45589fBad3A1FB90F5b2A8A3E8958a8BAB5f768);
      IERC20Upgradeable chapelTUsd = IERC20Upgradeable(0x4f1885D25eF219D3D4Fa064809D6D4985FAb9A0b);
      XBombSwap xbombSwap = XBombSwap(0x47Bf57bB81c82Af4116cA2FF76D063C698cFCd76);

      if (inputToken == chapelBomb) {
        strategyData = abi.encode(xbombSwap, xbombSwap, chapelTUsd);
      } else if (inputToken == chapelTUsd) {
        strategyData = abi.encode(chapelTUsd, xbombSwap, chapelTUsd);
      }
    } else {
      address xbomb = 0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b;
      address bomb = 0x522348779DCb2911539e76A1042aA922F9C47Ee3;
      strategyData = abi.encode(inputToken, xbomb, bomb);
    }
  }
}
