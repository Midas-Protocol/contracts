// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./ILiquidatorsRegistry.sol";
import "./LiquidatorsRegistryStorage.sol";

import "../IRedemptionStrategy.sol";
import "../../midas/DiamondExtension.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";

import { IRouter } from "../../external/solidly/IRouter.sol";
import { IPair } from "../../external/solidly/IPair.sol";
import { IUniswapV2Pair } from "../../external/uniswap/IUniswapV2Pair.sol";

import { CurveLpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import { CurveV2LpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveV2LpTokenPriceOracleNoRegistry.sol";
import { SaddleLpPriceOracle } from "../../oracles/default/SaddleLpPriceOracle.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { XBombSwap } from "../XBombLiquidatorFunder.sol";

contract LiquidatorsRegistryExtension is LiquidatorsRegistryStorage, DiamondExtension, ILiquidatorsRegistryExtension {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error NoRedemptionPath();
  error OutputTokenMismatch();

  function _getExtensionFunctions() external pure override returns (bytes4[] memory) {
    uint8 fnsCount = 12;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.getRedemptionStrategies.selector;
    functionSelectors[--fnsCount] = this.getRedemptionStrategy.selector;
    functionSelectors[--fnsCount] = this._setDefaultOutputToken.selector;
    functionSelectors[--fnsCount] = this._setRedemptionStrategy.selector;
    functionSelectors[--fnsCount] = this._setRedemptionStrategies.selector;
    functionSelectors[--fnsCount] = this._removeRedemptionStrategy.selector;
    functionSelectors[--fnsCount] = this.getInputTokensByOutputToken.selector;
    functionSelectors[--fnsCount] = this.swap.selector;
    functionSelectors[--fnsCount] = this.getAllRedemptionStrategies.selector;
    functionSelectors[--fnsCount] = this._removeDirectSwapStep.selector;
    functionSelectors[--fnsCount] = this._resetRedemptionStrategies.selector;
    functionSelectors[--fnsCount] = this.amountOutAndSlippageOfSwap.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }

  function getAllRedemptionStrategies() public view returns (address[] memory) {
    return redemptionStrategies.values();
  }

  function amountOutAndSlippageOfSwap(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IERC20Upgradeable outputToken
  ) external returns (uint256 outputAmount, uint256 slippage) {
    if (inputAmount == 0) return (0, 0);

    outputAmount = swap(inputToken, inputAmount, outputToken);
    if (outputAmount == 0) return (0, 0);

    MasterPriceOracle mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    uint256 inputTokenPrice = mpo.price(address(inputToken));
    uint256 outputTokenPrice = mpo.price(address(outputToken));

    uint256 inputTokensValue = inputAmount * toScaledPrice(inputTokenPrice, inputToken);
    uint256 outputTokensValue = outputAmount * toScaledPrice(outputTokenPrice, outputToken);

    slippage = ((inputTokensValue - outputTokensValue) * 1e18) / inputTokensValue;
  }

  /// @dev returns price scaled to 1e36 - decimals
  function toScaledPrice(uint256 unscaledPrice, IERC20Upgradeable token) internal returns (uint256) {
    uint256 tokenDecimals = uint256(ERC20Upgradeable(address(token)).decimals());
    return
      tokenDecimals <= 18
        ? uint256(unscaledPrice) * (10**(18 - tokenDecimals))
        : uint256(unscaledPrice) / (10**(tokenDecimals - 18));
  }

  function swap(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IERC20Upgradeable outputToken
  ) public returns (uint256 outputAmount) {
    inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);
    outputAmount = convertAllTo(inputToken, outputToken);
    outputToken.safeTransfer(msg.sender, outputAmount);
  }

  function convertAllTo(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) private returns (uint256) {
    uint256 inputAmount = inputToken.balanceOf(address(this));
    (IRedemptionStrategy[] memory redemptionStrategies, bytes[] memory strategiesData) = getRedemptionStrategies(
      inputToken,
      outputToken
    );

    if (redemptionStrategies.length == 0) revert NoRedemptionPath();

    IERC20Upgradeable swapInputToken = inputToken;
    uint256 swapInputAmount = inputAmount;
    for (uint256 i = 0; i < redemptionStrategies.length; i++) {
      IRedemptionStrategy redemptionStrategy = redemptionStrategies[i];
      bytes memory strategyData = strategiesData[i];
      (IERC20Upgradeable swapOutputToken, uint256 swapOutputAmount) = convertCustomFunds(
        swapInputToken,
        swapInputAmount,
        redemptionStrategy,
        strategyData
      );
      swapInputAmount = swapOutputAmount;
      swapInputToken = swapOutputToken;
    }

    if (swapInputToken != outputToken) revert OutputTokenMismatch();
    return outputToken.balanceOf(address(this));
  }

  function convertCustomFunds(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IRedemptionStrategy strategy,
    bytes memory strategyData
  ) private returns (IERC20Upgradeable, uint256) {
    bytes memory returndata = _functionDelegateCall(
      address(strategy),
      abi.encodeWithSelector(strategy.redeem.selector, inputToken, inputAmount, strategyData)
    );
    return abi.decode(returndata, (IERC20Upgradeable, uint256));
  }

  function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
    require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");
    (bool success, bytes memory returndata) = target.delegatecall(data);
    return _verifyCallResult(success, returndata, "Address: low-level delegate call failed");
  }

  function _verifyCallResult(
    bool success,
    bytes memory returndata,
    string memory errorMessage
  ) private pure returns (bytes memory) {
    if (success) {
      return returndata;
    } else {
      if (returndata.length > 0) {
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }
  }

  function getInputTokensByOutputToken(IERC20Upgradeable outputToken) external view returns (address[] memory) {
    return inputTokensByOutputToken[outputToken].values();
  }

  function _addInputTokenForOutputToken(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    onlyOwner
    returns (bool)
  {
    return inputTokensByOutputToken[outputToken].add(address(inputToken));
  }

  function _setDefaultOutputToken(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external onlyOwner {
    defaultOutputToken[inputToken] = outputToken;
  }

  function _setRedemptionStrategy(
    IRedemptionStrategy strategy,
    IERC20Upgradeable inputToken,
    IERC20Upgradeable outputToken
  ) public onlyOwner {
    string memory name = strategy.name();
    IRedemptionStrategy oldStrategy = redemptionStrategiesByName[name];

    redemptionStrategiesByTokens[inputToken][outputToken] = strategy;
    redemptionStrategiesByName[name] = strategy;

    redemptionStrategies.remove(address(oldStrategy));
    redemptionStrategies.add(address(strategy));

    if (defaultOutputToken[inputToken] == IERC20Upgradeable(address(0))) {
      defaultOutputToken[inputToken] = outputToken;
    }
    inputTokensByOutputToken[outputToken].add(address(inputToken));
    outputTokensSet.add(address(outputToken));
  }

  function _setRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens
  ) external onlyOwner {
    require(strategies.length == inputTokens.length && inputTokens.length == outputTokens.length, "!arrays len");
    for (uint256 i = 0; i < strategies.length; i++) {
      _setRedemptionStrategy(strategies[i], inputTokens[i], outputTokens[i]);
    }
  }

  function _resetRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens
  ) external onlyOwner {
    require(strategies.length == inputTokens.length && inputTokens.length == outputTokens.length, "!arrays len");

    // empty the input/output token mappings/sets
    address[] memory _outputTokens = outputTokensSet.values();
    for (uint256 i = 0; i < _outputTokens.length; i++) {
      IERC20Upgradeable _outputToken = IERC20Upgradeable(_outputTokens[i]);
      address[] memory _inputTokens = inputTokensByOutputToken[_outputToken].values();
      for (uint256 j = 0; j < _inputTokens.length; j++) {
        IERC20Upgradeable _inputToken = IERC20Upgradeable(_inputTokens[i]);
        redemptionStrategiesByTokens[_inputToken][_outputToken] = IRedemptionStrategy(address(0));
        inputTokensByOutputToken[_outputToken].remove(_inputTokens[i]);
        defaultOutputToken[_inputToken] = IERC20Upgradeable(address(0));
      }
      outputTokensSet.remove(_outputTokens[i]);
    }

    // empty the strategies mappings/sets
    address[] memory _currentStrategies = redemptionStrategies.values();
    for (uint256 i = 0; i < _currentStrategies.length; i++) {
      IRedemptionStrategy _currentStrategy = IRedemptionStrategy(_currentStrategies[i]);
      string memory _name = _currentStrategy.name();
      redemptionStrategiesByName[_name] = IRedemptionStrategy(address(0));
      redemptionStrategies.remove(_currentStrategies[i]);
    }

    // write the new strategies and their tokens configs
    for (uint256 i = 0; i < strategies.length; i++) {
      _setRedemptionStrategy(strategies[i], inputTokens[i], outputTokens[i]);
    }
  }

  function _removeRedemptionStrategy(
    address strategyToRemove,
    string calldata name,
    IERC20Upgradeable inputToken
  ) external onlyOwner {
    IERC20Upgradeable outputToken = defaultOutputToken[inputToken];

    redemptionStrategiesByName[name] = IRedemptionStrategy(address(0));
    redemptionStrategiesByTokens[inputToken][outputToken] = IRedemptionStrategy(address(0));
    defaultOutputToken[inputToken] = IERC20Upgradeable(address(0));
    inputTokensByOutputToken[outputToken].remove(address(inputToken));
    redemptionStrategies.remove(strategyToRemove);
  }

  function _removeDirectSwapStep(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external onlyOwner {
    IERC20Upgradeable defaultOutToken = defaultOutputToken[inputToken];
    if (defaultOutToken == outputToken) defaultOutputToken[inputToken] = IERC20Upgradeable(address(0));
    redemptionStrategiesByTokens[inputToken][outputToken] = IRedemptionStrategy(address(0));
    inputTokensByOutputToken[outputToken].remove(address(inputToken));
  }

  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    public
    view
    returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData)
  {
    IERC20Upgradeable tokenToRedeem = inputToken;
    IERC20Upgradeable targetOutputToken = outputToken;
    IRedemptionStrategy[] memory strategiesTemp = new IRedemptionStrategy[](10);
    bytes[] memory strategiesDataTemp = new bytes[](10);
    IERC20Upgradeable[] memory tokenPath = new IERC20Upgradeable[](10);

    uint256 k = 0;
    while (tokenToRedeem != targetOutputToken) {
      IERC20Upgradeable nextRedeemedToken;
      IRedemptionStrategy directStrategy = redemptionStrategiesByTokens[tokenToRedeem][targetOutputToken];
      if (address(directStrategy) != address(0)) {
        nextRedeemedToken = targetOutputToken;
      } else {
        // chain the next redeemed token from the default path
        nextRedeemedToken = defaultOutputToken[tokenToRedeem];
        for (uint256 i = 0; i < tokenPath.length; i++) {
          if (nextRedeemedToken == tokenPath[i]) break;
        }
      }

      (IRedemptionStrategy strategy, bytes memory strategyData) = getRedemptionStrategy(
        tokenToRedeem,
        nextRedeemedToken
      );
      if (address(strategy) == address(0)) break;

      strategiesTemp[k] = strategy;
      strategiesDataTemp[k] = strategyData;
      tokenPath[k] = nextRedeemedToken;
      tokenToRedeem = nextRedeemedToken;

      k++;
      if (k == 10) break;
    }

    strategies = new IRedemptionStrategy[](k);
    strategiesData = new bytes[](k);

    for (uint8 i = 0; i < k; i++) {
      strategies[i] = strategiesTemp[i];
      strategiesData[i] = strategiesDataTemp[i];
    }
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
    } else if (isStrategy(strategy, "AlgebraSwapLiquidator") || isStrategy(strategy, "GammaLpTokenLiquidator")) {
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
    } else if (isStrategy(strategy, "BalancerLinearPoolTokenLiquidator")) {
      strategyData = balancerLinearPoolTokenLiquidatorData(inputToken, outputToken);
      //} else if (isStrategy(strategy, "ERC4626Liquidator")) {
      //   TODO strategyData = erc4626LiquidatorData(inputToken, outputToken);
    }
  }

  function isStrategy(IRedemptionStrategy strategy, string memory name) internal view returns (bool) {
    return address(strategy) != address(0) && address(strategy) == address(redemptionStrategiesByName[name]);
  }

  function pickPreferredToken(address[] memory tokens, address strategyOutputToken) internal view returns (address) {
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == strategyOutputToken) return strategyOutputToken;
    }
    address wnative = ap.getAddress("wtoken");
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == wnative) return wnative;
    }
    address stableToken = ap.getAddress("stableToken");
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == stableToken) return stableToken;
    }
    address wbtc = ap.getAddress("wBTCToken");
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
    IRouter solidlyRouter = IRouter(ap.getAddress("SOLIDLY_SWAP_ROUTER"));
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

    strategyData = abi.encode(ap.getAddress("SOLIDLY_SWAP_ROUTER"), outputToken);
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
    strategyData = abi.encode(outputToken, ap.getAddress("ALGEBRA_SWAP_ROUTER"));
  }

  function uniswapLpTokenLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    IUniswapV2Pair lpToken = IUniswapV2Pair(address(inputToken));
    address token0 = lpToken.token0();
    address token1 = lpToken.token1();
    bool token0IsOutputToken = address(outputToken) == token0;
    bool token1IsOutputToken = address(outputToken) == token1;
    require(token0IsOutputToken || token1IsOutputToken, "Output token does not match either of the pair tokens");

    address[] memory swap0Path;
    address[] memory swap1Path;
    {
      if (token0IsOutputToken) {
        swap0Path = new address[](0);
        swap1Path = new address[](2);
        swap1Path[0] = token1;
        swap1Path[1] = token0;
      } else {
        swap1Path = new address[](0);
        swap0Path = new address[](2);
        swap0Path[0] = token0;
        swap0Path[1] = token1;
      }
    }

    strategyData = abi.encode(getUniswapV2Router(inputToken), swap0Path, swap1Path);
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

    address preferredToken = pickPreferredToken(tokens, address(outputToken));
    address actualOutputToken = preferredToken;
    address wnative = ap.getAddress("wtoken");
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

  function balancerLinearPoolTokenLiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    address poolAddress = ap.getBalancerPoolForTokens(address(inputToken), address(outputToken));
    // TODO remove after the pools are configure on-chain
    if (poolAddress == address(0)) {
      address wnative = ap.getAddress("wtoken");
      address stmatic = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;
      address maticx = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
      address twoeur = 0x513CdEE00251F39DE280d9E5f771A6eaFebCc88E;
      address par = 0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128;
      address maticxBbaWmatic = 0xE78b25c06dB117fdF8F98583CDaaa6c92B79E917;

      if (
        (address(inputToken) == wnative && address(outputToken) == stmatic) ||
        (address(inputToken) == stmatic && address(outputToken) == wnative)
      ) {
        poolAddress = 0x8159462d255C1D24915CB51ec361F700174cD994; // Balancer stMATIC Stable Pool
      }
      if (
        (address(inputToken) == wnative && address(outputToken) == maticx) ||
        (address(inputToken) == maticx && address(outputToken) == wnative)
      ) {
        poolAddress = 0xb20fC01D21A50d2C734C4a1262B4404d41fA7BF0; // Balancer MaticX Stable Pool
      }
      if (
        (address(inputToken) == par && address(outputToken) == twoeur) ||
        (address(inputToken) == twoeur && address(outputToken) == par)
      ) {
        poolAddress = twoeur; // Balancer 2EUR Stable Pool
      }
      if (
        (address(inputToken) == maticxBbaWmatic && address(outputToken) == maticx) ||
        (address(inputToken) == maticx && address(outputToken) == maticxBbaWmatic)
      ) {
        poolAddress = maticxBbaWmatic;
      }
    }

    strategyData = abi.encode(poolAddress, outputToken);
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
      IERC20Upgradeable chapelTDai = IERC20Upgradeable(0x8870f7102F1DcB1c35b01af10f1baF1B00aD6805);
      XBombSwap xbombSwapTUsd = XBombSwap(0x161FbE0943Af4A39a50262026A81a243B635982d);
      XBombSwap xbombSwapTDai = XBombSwap(0xd816eb4660615BBF080ddf425F28ea4AF30d04D5);

      if (inputToken == chapelBomb) {
        XBombSwap bombSwap;
        if (outputToken == chapelTUsd) {
          bombSwap = xbombSwapTUsd;
        } else if (outputToken == chapelTDai) {
          bombSwap = xbombSwapTDai;
        }
        strategyData = abi.encode(bombSwap, bombSwap, outputToken, outputToken);
      } else if (inputToken == chapelTUsd) {
        strategyData = abi.encode(inputToken, xbombSwapTUsd, inputToken, chapelBomb);
      } else if (inputToken == chapelTDai) {
        strategyData = abi.encode(inputToken, xbombSwapTDai, inputToken, chapelBomb);
      }
    } else {
      address xbomb = 0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b;
      address bomb = 0x522348779DCb2911539e76A1042aA922F9C47Ee3;
      strategyData = abi.encode(inputToken, xbomb, bomb);
    }
  }

  // @notice addresses hardcoded, use only for ETHEREUM
  function erc4626LiquidatorData(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    internal
    view
    returns (bytes memory strategyData)
  {
    uint256 fee;
    address[] memory underlyingTokens;
    address inputTokenAddr = address(inputToken);
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address realYieldUSD = 0x97e6E0a40a3D02F12d1cEC30ebfbAE04e37C119E;
    address ethBtcTrend = 0x6b7f87279982d919Bbf85182DDeAB179B366D8f2;
    address ethBtcMomentum = address(255); // TODO

    if (inputTokenAddr == realYieldUSD) {
      fee = 10;
      underlyingTokens = new address[](3);
      underlyingTokens[0] = usdc;
      underlyingTokens[1] = dai;
      underlyingTokens[2] = usdt;
    } else if (inputTokenAddr == ethBtcMomentum || inputTokenAddr == ethBtcTrend) {
      fee = 500;
      underlyingTokens = new address[](3);
      underlyingTokens[0] = usdc;
      underlyingTokens[1] = weth;
      underlyingTokens[2] = wbtc;
    } else {
      fee = 300;
      underlyingTokens = new address[](1);
      underlyingTokens[0] = address(outputToken);
    }

    strategyData = abi.encode(
      outputToken,
      fee,
      ap.getAddress("UNISWAP_V3_ROUTER"),
      underlyingTokens,
      ap.getAddress("Quoter")
    );
  }
}
