// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { FuseSafeLiquidator } from "../FuseSafeLiquidator.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { BaseTest } from "./config/BaseTest.t.sol";
import { AddressesProvider } from "../midas/AddressesProvider.sol";
import { CurveLpTokenPriceOracleNoRegistry } from "../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import { ICurvePool } from "../external/curve/ICurvePool.sol";
import { IFundsConversionStrategy } from "../liquidators/IFundsConversionStrategy.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { IUniswapV2Router02 } from "../external/uniswap/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../external/uniswap/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "../external/uniswap/IUniswapV2Factory.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";

contract AnyLiquidationTest is BaseTest {
  FuseSafeLiquidator fsl;
  address uniswapRouter;
  mapping(address => address) assetSpecificRouters;
  CurveLpTokenPriceOracleNoRegistry curveOracle;

  IFundsConversionStrategy[] fundingStrategies;
  bytes[] fundingDatas;

  IRedemptionStrategy[] redemptionStrategies;
  bytes[] redemptionDatas;

  IUniswapV2Pair mostLiquidPair1;
  IUniswapV2Pair mostLiquidPair2;

  function upgradeAp() internal {
    bytes32 _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    AddressesProvider newImpl = new AddressesProvider();
    newImpl.initialize(address(this));
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(ap)));
    bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
    address admin = address(uint160(uint256(bytesAtSlot)));
    vm.prank(admin);
    proxy.upgradeTo(address(newImpl));
  }

  function afterForkSetUp() internal override {
    upgradeAp();

    uniswapRouter = ap.getAddress("IUniswapV2Router02");

    if (block.chainid == BSC_MAINNET) {
      mostLiquidPair1 = IUniswapV2Pair(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16); // WBNB-BUSD
      mostLiquidPair2 = IUniswapV2Pair(0x61EB789d75A95CAa3fF50ed7E47b96c132fEc082); // WBNB-BTCB
      curveOracle = CurveLpTokenPriceOracleNoRegistry(0x4544d21EB5B368b3f8F98DcBd03f28aC0Cf6A0CA);
      // TODO revert to the ap provided, no need to upgrade after the next deploy
      // fsl = FuseSafeLiquidator(payable(ap.getAddress("FuseSafeLiquidator")));
      fsl = new FuseSafeLiquidator();
      fsl.initialize(
        ap.getAddress("wtoken"),
        uniswapRouter,
        ap.getAddress("stableToken"),
        ap.getAddress("wBTCToken"),
        "0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5",
        25
      );

      // TODO configure in the AP?
      address bnbx = 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275;
      address apeSwapRouter = 0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7;
      assetSpecificRouters[bnbx] = apeSwapRouter;
    } else if (block.chainid == POLYGON_MAINNET) {
      mostLiquidPair1 = IUniswapV2Pair(0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827); // USDC/WMATIC
      mostLiquidPair2 = IUniswapV2Pair(0x369582d2010B6eD950B571F4101e3bB9b554876F); // SAND/WMATIC
      curveOracle = CurveLpTokenPriceOracleNoRegistry(0xaCF3E1C6f2D6Ff12B8aEE44413D6834774B3f7A3);
      fsl = FuseSafeLiquidator(payable(ap.getAddress("FuseSafeLiquidator")));
      //      fsl = new FuseSafeLiquidator();
      //      fsl.initialize(
      //        ap.getAddress("wtoken"),
      //        uniswapRouter,
      //        ap.getAddress("stableToken"),
      //        ap.getAddress("wBTCToken"),
      //        "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f",
      //        30
      //      );
    }
  }

  //  function testSpecificRandom() public {
  //    testBscAnyLiquidation(283);
  //  }

  function testBscAnyLiquidation(uint256 random) public fork(BSC_MAINNET) {
    vm.assume(random > 100 && random < type(uint64).max);
    doTestAnyLiquidation(random);
  }

  function testPolygonAnyLiquidation(uint256 random) public fork(POLYGON_MAINNET) {
    vm.assume(random > 100 && random < type(uint64).max);
    doTestAnyLiquidation(random);
  }

  struct LiquidationData {
    FusePoolDirectory.FusePool[] pools;
    address[] cTokens;
    IRedemptionStrategy[] strategies;
    bytes[] redemptionDatas;
    ICToken[] markets;
    address[] borrowers;
    FuseSafeLiquidator liquidator;
    IFundsConversionStrategy[] fundingStrategies;
    bytes[] fundingDatas;
    ICErc20 debtMarket;
    ICErc20 collateralMarket;
    IComptroller comptroller;
    address borrower;
    uint256 borrowAmount;
    address flashSwapFundingToken;
    IUniswapV2Pair flashSwapPair;
  }

  function getPoolAndBorrower(uint256 random, LiquidationData memory vars)
    internal
    view
    returns (IComptroller, address)
  {
    if (vars.pools.length == 0) revert("no pools to pick from");

    uint256 i = random % vars.pools.length; // random pool
    IComptroller comptroller = IComptroller(vars.pools[i].comptroller);

    address bscBombPool = 0x5373C052Df65b317e48D6CAD8Bb8AC50995e9459;
    if (address(comptroller) == bscBombPool) {
      // we don't want to deal with the bomb liquidations
      return (IComptroller(address(0)), address(0));
    }

    address[] memory borrowers = comptroller.getAllBorrowers();

    if (borrowers.length == 0) {
      return (IComptroller(address(0)), address(0));
    } else {
      uint256 k = random % borrowers.length; // random borrower
      address borrower = borrowers[k];

      return (comptroller, borrower);
    }
  }

  function setUpDebtAndCollateralMarkets(uint256 random, LiquidationData memory vars)
    internal
    returns (
      ICErc20 debtMarket,
      ICErc20 collateralMarket,
      uint256 borrowAmount
    )
  {
    // find a debt market in which the borrower has borrowed
    for (uint256 m = 0; m < vars.markets.length; m++) {
      uint256 marketIndexWithOffset = (random + m) % vars.markets.length;
      ICToken randomMarket = vars.markets[marketIndexWithOffset];
      borrowAmount = randomMarket.borrowBalanceStored(vars.borrower);
      if (borrowAmount > 0) {
        debtMarket = ICErc20(address(randomMarket));
        break;
      }
    }

    if (address(debtMarket) != address(0)) {
      emit log("debt market is");
      emit log_address(address(debtMarket));

      uint256 shortfall = 0;
      // reduce the price of the collateral for each market where the borrower has supplied
      // until there is shortfall for which to be liquidated
      for (uint256 m = 0; m < vars.markets.length; m++) {
        uint256 marketIndexWithOffset = (random - m) % vars.markets.length;
        ICToken randomMarket = vars.markets[marketIndexWithOffset];
        uint256 borrowerCollateral = randomMarket.balanceOf(vars.borrower);
        if (borrowerCollateral > 0) {
          if (address(randomMarket) == address(debtMarket)) continue;

          // the collateral prices change
          MasterPriceOracle mpo = MasterPriceOracle(address(vars.comptroller.oracle()));
          uint256 priceCollateral = mpo.getUnderlyingPrice(randomMarket);
          vm.mockCall(
            address(mpo),
            abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, randomMarket),
            abi.encode(priceCollateral / 5)
          );

          uint256 collateralValue = borrowerCollateral * (priceCollateral / 5);
          uint256 borrowValue = borrowAmount * mpo.getUnderlyingPrice(debtMarket);

          if (collateralValue < borrowValue) {
            emit log("collateral position too small");
            continue;
          }

          (, , shortfall) = vars.comptroller.getHypotheticalAccountLiquidity(vars.borrower, address(0), 0, 0);
          if (shortfall == 0) {
            emit log("collateral still enough");
            continue;
          } else {
            emit log("has shortfall");
            collateralMarket = ICErc20(address(randomMarket));
            break;
          }
        }
      }
      if (shortfall == 0) {
        return (ICErc20(address(0)), ICErc20(address(0)), 0);
      }
    }
  }

  function doTestAnyLiquidation(uint256 random) internal {
    LiquidationData memory vars;
    vars.liquidator = fsl;

    vars.pools = FusePoolDirectory(ap.getAddress("FusePoolDirectory")).getAllPools();

    while (true) {
      // get a random pool and a random borrower from it
      (vars.comptroller, vars.borrower) = getPoolAndBorrower(random, vars);

      if (address(vars.comptroller) != address(0) && vars.borrower != address(0)) {
        // find a market in which the borrower has debt and reduce his collateral price
        vars.markets = vars.comptroller.getAllMarkets();
        (vars.debtMarket, vars.collateralMarket, vars.borrowAmount) = setUpDebtAndCollateralMarkets(random, vars);

        // TODO implement redemption straegies for these collaterals
        address bscBnbxMarket = 0xa47A7672EF042Ec2838E9425C083Efd982BFa362;
        address mimo80par20Market = 0xcb67Bd2aE0597eDb2426802CdF34bb4085d9483A;
        if (address(vars.debtMarket) != address(0) && address(vars.collateralMarket) != address(0)) {
          if (
            vars.debtMarket.underlying() != ap.getAddress("wtoken") &&
            address(vars.collateralMarket) != bscBnbxMarket &&
            address(vars.collateralMarket) != mimo80par20Market
          ) {
            emit log("found testable markets at random number");
            emit log_uint(random);
            break;
          }
        }
      }
      random++;
    }

    emit log("debt and collateral markets");
    emit log_address(address(vars.debtMarket));
    emit log_address(address(vars.collateralMarket));

    // prepare the liquidation

    // add funding strategies
    {
      address debtTokenToFund = vars.debtMarket.underlying();

      uint256 i = 0;
      while (true) {
        emit log("funding token");
        emit log_address(debtTokenToFund);
        if (i++ > 10) revert("endless loop bad");

        AddressesProvider.FundingStrategy memory strategy = ap.getFundingStrategy(debtTokenToFund);
        if (strategy.addr == address(0)) break;

        debtTokenToFund = addFundingStrategy(
          vars,
          IFundsConversionStrategy(strategy.addr),
          debtTokenToFund,
          strategy.contractInterface,
          strategy.inputToken
        );
      }

      vars.flashSwapFundingToken = debtTokenToFund;
      if (vars.flashSwapFundingToken != ap.getAddress("wtoken")) {
        IUniswapV2Router02 router = IUniswapV2Router02(uniswapRouter);
        address pairAddress = IUniswapV2Factory(router.factory()).getPair(
          vars.flashSwapFundingToken,
          ap.getAddress("wtoken")
        );
        if (pairAddress != address(0)) {
          vars.flashSwapPair = IUniswapV2Pair(pairAddress);
        } else {
          revert("no pair for flash swap funding");
        }
      } else {
        vars.flashSwapPair = IUniswapV2Pair(mostLiquidPair1);
      }

      vars.fundingStrategies = fundingStrategies;
      vars.fundingDatas = fundingDatas;
    }

    emit log("flash swap funding token is");
    emit log_address(vars.flashSwapFundingToken);

    address exchangeCollateralTo = vars.flashSwapFundingToken;

    // add the redemption strategies
    if (exchangeCollateralTo != address(0)) {
      address collateralTokenToRedeem = vars.collateralMarket.underlying();
      while (collateralTokenToRedeem != exchangeCollateralTo) {
        AddressesProvider.RedemptionStrategy memory strategy = ap.getRedemptionStrategy(collateralTokenToRedeem);
        if (strategy.addr == address(0)) break;
        collateralTokenToRedeem = addRedemptionStrategy(
          vars,
          IRedemptionStrategy(strategy.addr),
          strategy.contractInterface,
          collateralTokenToRedeem,
          strategy.outputToken
        );
      }
      vars.redemptionDatas = redemptionDatas;
      vars.strategies = redemptionStrategies;
    }

    // liquidate
    vm.prank(ap.owner());
    try
      vars.liquidator.safeLiquidateToTokensWithFlashLoan(
        FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
          vars.borrower,
          vars.borrowAmount / 100,
          ICErc20(address(vars.debtMarket)),
          ICErc20(address(vars.collateralMarket)),
          vars.flashSwapPair,
          0,
          exchangeCollateralTo,
          IUniswapV2Router02(uniswapRouter), // TODO ASSET_SPECIFIC_ROUTER
          IUniswapV2Router02(uniswapRouter), // TODO ASSET_SPECIFIC_ROUTER
          vars.strategies,
          vars.redemptionDatas,
          0,
          vars.fundingStrategies,
          vars.fundingDatas
        )
      )
    {
      // noop
    } catch Error(string memory reason) {
      if (compareStrings(reason, "Number of tokens less than minimum limit")) {
        emit log("jarvis pool failing, that's ok");
      } else {
        revert(reason);
      }
    }
  }

  function getUniswapV2Router(address inputToken) internal view returns (address) {
    address router = assetSpecificRouters[inputToken];
    return router != address(0) ? router : uniswapRouter;
  }

  function toggleFlashSwapPair(LiquidationData memory vars) internal view {
    if (address(vars.flashSwapPair) == address(mostLiquidPair1)) {
      vars.flashSwapPair = mostLiquidPair2;
    } else {
      vars.flashSwapPair = mostLiquidPair1;
    }
  }

  function addRedemptionStrategy(
    LiquidationData memory vars,
    IRedemptionStrategy strategy,
    string memory strategyContract,
    address inputToken,
    address strategyOutputToken
  ) internal returns (address) {
    address outputToken;
    bytes memory strategyData;

    if (compareStrings(strategyContract, "UniswapLpTokenLiquidator")) {
      IUniswapV2Pair pair = IUniswapV2Pair(inputToken);
      address[] memory swapToken0Path;
      address[] memory swapToken1Path;

      if (pair.token0() == strategyOutputToken) {
        swapToken0Path = new address[](0);
        swapToken1Path = new address[](2);

        swapToken1Path[0] = pair.token1();
        swapToken1Path[1] = pair.token0();
        outputToken = swapToken1Path[1];
      } else {
        swapToken0Path = new address[](2);
        swapToken1Path = new address[](0);

        swapToken0Path[0] = pair.token0();
        swapToken0Path[1] = pair.token1();
        outputToken = swapToken0Path[1];
      }

      strategyData = abi.encode(uniswapRouter, swapToken0Path, swapToken1Path);

      if (address(vars.flashSwapPair) == address(pair)) {
        emit log("toggling the flashswap pair");
        emit log_address(address(pair));
        toggleFlashSwapPair(vars);
      }
    } else if (compareStrings(strategyContract, "UniswapV2LiquidatorFunder")) {
      outputToken = strategyOutputToken;

      address[] memory swapPath = new address[](2);
      swapPath[0] = inputToken;
      swapPath[1] = outputToken;

      strategyData = abi.encode(getUniswapV2Router(inputToken), swapPath);
    } else if (compareStrings(strategyContract, "JarvisLiquidatorFunder")) {
      AddressesProvider.JarvisPool[] memory pools = ap.getJarvisPools();
      for (uint256 i = 0; i < pools.length; i++) {
        AddressesProvider.JarvisPool memory pool = pools[i];
        if (pool.syntheticToken == inputToken) {
          strategyData = abi.encode(pool.syntheticToken, pool.liquidityPool, pool.expirationTime);
          outputToken = pool.collateralToken;
          break;
        }
      }
    } else if (compareStrings(strategyContract, "CurveSwapLiquidator")) {
      outputToken = strategyOutputToken;

      AddressesProvider.CurveSwapPool[] memory curveSwapPools = ap.getCurveSwapPools();
      for (uint256 i = 0; i < curveSwapPools.length; i++) {
        if (curveSwapPools[i].poolAddress == inputToken) {
          emit log_address(inputToken);
          emit log_address(strategyOutputToken);
          revert("use the CurveLpTokenLiquidatorNoRegistry for the redemption of LP tokens");
        }
      }

      int128 outputIndex;
      int128 inputIndex;
      address poolAddress;
      for (uint256 i = 0; i < curveSwapPools.length; i++) {
        outputIndex = -1;
        inputIndex = -1;
        poolAddress = curveSwapPools[i].poolAddress;
        ICurvePool curvePool = ICurvePool(poolAddress);
        int128 j = 0;
        while (true) {
          try curvePool.coins(uint256(int256(j))) returns (address coin) {
            if (coin == outputToken) outputIndex = j;
            else if (coin == inputToken) inputIndex = j;
          } catch {
            break;
          }
          j++;
        }
        if (outputIndex >= 0 && inputIndex >= 0) break;
      }

      if (outputIndex == -1 || inputIndex == -1) {
        emit log("input token");
        emit log_address(inputToken);
        emit log("output token");
        emit log_address(outputToken);
        revert("failed to find curve pool");
      }

      strategyData = abi.encode(poolAddress, inputIndex, outputIndex, outputToken, ap.getAddress("wtoken"));
    } else if (compareStrings(strategyContract, "CurveLpTokenLiquidatorNoRegistry")) {
      address[] memory underlyingTokens = getCurvePoolUnderlyingTokens(curveOracle.poolOf(inputToken));
      (address preferredOutputToken, uint8 outputTokenIndex) = pickPreferredToken(
        underlyingTokens,
        strategyOutputToken
      );
      emit log("preferred token");
      emit log_address(preferredOutputToken);
      emit log_uint(outputTokenIndex);
      outputToken = preferredOutputToken;
      if (outputToken == address(0) || outputToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
        outputToken = ap.getAddress("wtoken");
      }

      strategyData = abi.encode(outputTokenIndex, preferredOutputToken, ap.getAddress("wtoken"), address(curveOracle));
    } else if (compareStrings(strategyContract, "XBombLiquidatorFunder")) {
      outputToken = strategyOutputToken;
      address xbomb = inputToken;
      address bomb = outputToken;
      strategyData = abi.encode(inputToken, xbomb, bomb);
    } else {
      emit log(strategyContract);
      emit log_address(address(strategy));
      revert("unknown collateral");
    }

    vm.prank(vars.liquidator.owner());
    vars.liquidator._whitelistRedemptionStrategy(strategy, true);
    redemptionStrategies.push(strategy);
    redemptionDatas.push(strategyData);

    assertEq(outputToken, strategyOutputToken, "!expected output token");
    return outputToken;
  }

  function getCurvePoolUnderlyingTokens(address lpTokenAddress) internal view returns (address[] memory) {
    ICurvePool curvePool = ICurvePool(lpTokenAddress);
    uint8 i = 0;
    while (true) {
      try curvePool.coins(i) {
        i++;
      } catch {
        break;
      }
    }
    address[] memory tokens = new address[](i);
    for (uint8 j = 0; j < i; j++) {
      tokens[j] = curvePool.coins(j);
    }
    return tokens;
  }

  function pickPreferredToken(address[] memory tokens, address strategyOutputToken)
    internal
    view
    returns (address, uint8)
  {
    address wtoken = ap.getAddress("wtoken");
    address stable = ap.getAddress("stableToken");
    address wbtc = ap.getAddress("wBTCToken");

    for (uint8 i = 0; i < tokens.length; i++) {
      if (tokens[i] == strategyOutputToken) return (strategyOutputToken, i);
    }
    for (uint8 i = 0; i < tokens.length; i++) {
      if (tokens[i] == wtoken) return (wtoken, i);
    }
    for (uint8 i = 0; i < tokens.length; i++) {
      if (tokens[i] == stable) return (stable, i);
    }
    for (uint8 i = 0; i < tokens.length; i++) {
      if (tokens[i] == wbtc) return (wbtc, i);
    }
    return (tokens[0], 0);
  }

  function addFundingStrategy(
    LiquidationData memory vars,
    IFundsConversionStrategy strategy,
    address debtToken,
    string memory strategyContract,
    address strategyInputToken
  ) internal returns (address) {
    address inputToken;
    bytes memory strategyData;

    if (compareStrings(strategyContract, "JarvisLiquidatorFunder")) {
      AddressesProvider.JarvisPool[] memory pools = ap.getJarvisPools();
      for (uint256 i = 0; i < pools.length; i++) {
        AddressesProvider.JarvisPool memory pool = pools[i];
        if (pool.syntheticToken == debtToken) {
          strategyData = abi.encode(pool.collateralToken, pool.liquidityPool, pool.expirationTime);
          inputToken = pool.collateralToken;
          break;
        }
      }

      // } else if (compareStrings(strategyContract, "SomeOtherFunder")) {
      // bytes memory strategyData = abi.encode(strategySpecificParams);
      // (IERC20Upgradeable inputToken, uint256 inputAmount) = IFundsConversionStrategy(addr).estimateInputAmount(10**(debtToken.decimals()), strategyData);
      // fundingStrategies.push(new SomeOtherFunder());
      // return inputToken;
    } else if (compareStrings(strategyContract, "CurveSwapLiquidatorFunder")) {
      int128 inputIndex;
      int128 outputIndex;
      inputToken = strategyInputToken;

      AddressesProvider.CurveSwapPool[] memory curveSwapPools = ap.getCurveSwapPools();

      address poolAddress;
      for (uint256 i = 0; i < curveSwapPools.length; i++) {
        poolAddress = curveSwapPools[i].poolAddress;
        if (poolAddress == debtToken || poolAddress == inputToken) {
          emit log_address(debtToken);
          emit log_address(inputToken);
          emit log_address(poolAddress);
          revert("no strategy available for funding with curve LP tokens");
        }

        inputIndex = -1;
        outputIndex = -1;
        ICurvePool curvePool = ICurvePool(poolAddress);
        int128 j = 0;
        while (true) {
          try curvePool.coins(uint256(int256(j))) returns (address coin) {
            if (coin == debtToken) outputIndex = j;
            else if (coin == inputToken) inputIndex = j;
          } catch {
            break;
          }
          j++;
        }
        if (outputIndex >= 0 && inputIndex >= 0) break;
      }

      if (outputIndex == -1 || inputIndex == -1) {
        emit log("curve swap input token");
        emit log_address(inputToken);
        emit log("curve swap debt token");
        emit log_address(debtToken);
        revert("failed to find curve pool");
      }

      strategyData = abi.encode(poolAddress, inputIndex, outputIndex, debtToken, ap.getAddress("wtoken"));
    } else if (compareStrings(strategyContract, "UniswapV3LiquidatorFunder")) {
      inputToken = strategyInputToken;

      uint24 fee = 1000;
      address quoter = ap.getAddress("Quoter");
      address swapRouter;
      {
        // TODO
        // polygon config // 0x1F98431c8aD98523631AE4a59f267346ea31F984
        address polygonSwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

        swapRouter = polygonSwapRouter;
        fee = 500;
      }

      strategyData = abi.encode(inputToken, debtToken, fee, swapRouter, quoter);
    } else {
      emit log(strategyContract);
      emit log_address(debtToken);
      revert("unknown debt token");
    }

    fundingDatas.push(strategyData);

    vm.prank(vars.liquidator.owner());
    vars.liquidator._whitelistRedemptionStrategy(strategy, true);
    fundingStrategies.push(strategy);

    assertEq(strategyInputToken, inputToken, "!expected input token");
    return inputToken;
  }
}
