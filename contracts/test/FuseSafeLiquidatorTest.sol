// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "./config/BaseTest.t.sol";
import "../FuseSafeLiquidator.sol";

contract MockRedemptionStrategy is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    return (IERC20Upgradeable(address(0)), 1);
  }
}

contract FuseSafeLiquidatorTest is BaseTest {
  FuseSafeLiquidator fsl;
  address uniswapRouter;

  function setNetworkValues(string memory network, uint256 forkBlockNumber) internal {
    vm.createSelectFork(vm.rpcUrl(network), forkBlockNumber);
    setAddressProvider(network);
  }

  function testBsc() public {
    setNetworkValues("bsc", 20238373);
    uniswapRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    fsl = FuseSafeLiquidator(payable(0xc9C3D317E89f4390A564D56180bBB1842CF3c99C));

    testWhitelistRevert();
    testWhitelist();
    testUpgrade();
  }

  function testPolygon() public {
    setNetworkValues("polygon", 33063212);
    uniswapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    fsl = FuseSafeLiquidator(payable(0x37b3890B9b3a5e158EAFDA243d4640c5349aFC15));

    testWhitelistRevert();
    testWhitelist();
    testUpgrade();
  }

  function testWhitelistRevert() internal {
    IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(address(0));
    uint256 underlyingCollateralSeized = 1;
    IRedemptionStrategy strategy = new MockRedemptionStrategy();
    bytes memory strategyData = "";

    vm.expectRevert("only whitelisted redemption strategies can be used");
    fsl.redeemCustomCollateral(underlyingCollateral, underlyingCollateralSeized, strategy, strategyData);
  }

  function testWhitelist() internal {
    IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(address(0));
    uint256 underlyingCollateralSeized = 1;
    IRedemptionStrategy strategy = new MockRedemptionStrategy();
    bytes memory strategyData = "";

    vm.prank(fsl.owner());
    fsl._whitelistRedemptionStrategy(strategy, true);
    fsl.redeemCustomCollateral(underlyingCollateral, underlyingCollateralSeized, strategy, strategyData);
  }

  function testUpgrade() internal {
    // in case these slots start to get used, please redeploy the FSL
    // with a larger storage gap to protect the owner variable of OwnableUpgradeable
    // from being overwritten by the FuseSafeLiquidator storage
    for (uint256 i = 40; i < 51; i++) {
      address atSloti = address(uint160(uint256(vm.load(address(fsl), bytes32(i)))));
      assertEq(
        atSloti,
        address(0),
        "replace the FSL proxy/storage contract with a new one before the owner variable is overwritten"
      );
    }
  }
}
<<<<<<< HEAD

contract AnyLiquidationTest is BaseTest {
  FuseSafeLiquidator fsl;
  address uniswapRouter;
  CurveLpTokenPriceOracleNoRegistry curveOracle;
  CurveSwapPool[] curveSwapPools;

  IFundsConversionStrategy[] fundingStrategies;
  bytes[] fundingDatas;

  IRedemptionStrategy[] redemptionStrategies;
  bytes[] redemptionDatas;

  CurveSwapLiquidator curveSwapLiquidator;
  JarvisLiquidatorFunder jarvisLiquidator;
  UniswapV2Liquidator uniswapV2Liquidator;
  CurveLpTokenLiquidatorNoRegistry curveLpTokenLiquidatorNoRegistry;

  IUniswapV2Pair mostLiquidPair1;
  IUniswapV2Pair mostLiquidPair2;

  struct CurveSwapPool {
    address pool;
    int128 preferredCoin;
  }

  function setNetworkValues(string memory network, uint256 forkBlockNumber) internal {
    vm.createSelectFork(vm.rpcUrl(network), forkBlockNumber);
    setAddressProvider(network);
  }

  // function testBsc(uint256 random) public {
  //   setNetworkValues("bsc", 22277940);
  //   curveSwapLiquidator = new CurveSwapLiquidator();
  //   jarvisLiquidator = new JarvisLiquidatorFunder();
  //   uniswapV2Liquidator = new UniswapV2Liquidator();
  //   curveLpTokenLiquidatorNoRegistry = new CurveLpTokenLiquidatorNoRegistry();
  //   uniswapRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
  //   mostLiquidPair1 = IUniswapV2Pair(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16); // WBNB-BUSD
  //   mostLiquidPair2 = IUniswapV2Pair(0x61EB789d75A95CAa3fF50ed7E47b96c132fEc082); // WBNB-BTCB
  //   configureBscRedemptionStrategies();
  //   curveOracle = CurveLpTokenPriceOracleNoRegistry(0x4544d21EB5B368b3f8F98DcBd03f28aC0Cf6A0CA);
  //   fsl = new FuseSafeLiquidator();
  //   fsl.initialize(
  //     ap.getAddress("wtoken"),
  //     uniswapRouter,
  //     ap.getAddress("bUSD"),
  //     ap.getAddress("wBTCToken"),
  //     "0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5",
  //     25
  //   );
  //   configureCurveSwapPools();
  //   testAnyLiquidation(random);
  // }

  // function testPolygon(uint256 random) public {
  //   setNetworkValues("polygon", 34489980);
  //   vm.rollFork(34489980);
  //   curveSwapLiquidator = new CurveSwapLiquidator();
  //   jarvisLiquidator = new JarvisLiquidatorFunder();
  //   uniswapV2Liquidator = new UniswapV2Liquidator();
  //   curveLpTokenLiquidatorNoRegistry = new CurveLpTokenLiquidatorNoRegistry();
  //   uniswapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
  //   mostLiquidPair1 = IUniswapV2Pair(0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827); // USDC/WMATIC
  //   mostLiquidPair2 = IUniswapV2Pair(0x369582d2010B6eD950B571F4101e3bB9b554876F); // SAND/WMATIC
  //   address usdcPolygon = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  //   curveOracle = CurveLpTokenPriceOracleNoRegistry(0xaCF3E1C6f2D6Ff12B8aEE44413D6834774B3f7A3);
  //   // fsl = FuseSafeLiquidator(payable(ap.getAddress("FuseSafeLiquidator")));
  //   fsl = new FuseSafeLiquidator();
  //   fsl.initialize(
  //     ap.getAddress("wtoken"),
  //     uniswapRouter,
  //     usdcPolygon,
  //     ap.getAddress("wBTCToken"),
  //     "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f",
  //     30
  //   );
  //   address ageurJeurPool = 0x2fFbCE9099cBed86984286A54e5932414aF4B717; // AGEUR_JEUR
  //   address jeurParPool = 0x0f110c55EfE62c16D553A3d3464B77e1853d0e97; // JEUR_PAR
  //   address jjpyJpycPool = 0xaA91CDD7abb47F821Cf07a2d38Cc8668DEAf1bdc; // JJPY_JPYC
  //   address jcadCadcPool = 0xA69b0D5c0C401BBA2d5162138613B5E38584F63F; // JCAD_CADC
  //   address jsgdXsgdPool = 0xeF75E9C7097842AcC5D0869E1dB4e5fDdf4BFDDA; // JSGD_XSGD
  //   address jnzdNzdsPool = 0x976A750168801F58E8AEdbCfF9328138D544cc09; // JNZD_NZDS
  //   address jeurEurtPool = 0x2C3cc8e698890271c8141be9F6fD6243d56B39f1; // JEUR_EUR
  //   address eureJeurPool = 0x2F3E9CA3bFf85B91D9fe6a9f3e8F9B1A6a4c3cF4; // EURE_JEUR
  //   curveSwapPools.push(CurveSwapPool(ageurJeurPool, 1));
  //   curveSwapPools.push(CurveSwapPool(jeurParPool, 1));
  //   curveSwapPools.push(CurveSwapPool(jjpyJpycPool, 0));
  //   curveSwapPools.push(CurveSwapPool(jcadCadcPool, 0));
  //   curveSwapPools.push(CurveSwapPool(jsgdXsgdPool, 0));
  //   curveSwapPools.push(CurveSwapPool(jnzdNzdsPool, 0));
  //   curveSwapPools.push(CurveSwapPool(jeurEurtPool, 1));
  //   curveSwapPools.push(CurveSwapPool(eureJeurPool, 1));
  //   configureCurveSwapPools();

  //   testAnyLiquidation(random);
  // }

  function configureBscRedemptionStrategies() internal {
    {
      address twoBrlAddress = 0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9;
      (address addr, ) = ap.redemptionStrategies(twoBrlAddress);
      if (addr == address(0)) {
        vm.prank(ap.owner());
        ap.setRedemptionStrategy(
          twoBrlAddress,
          address(curveLpTokenLiquidatorNoRegistry),
          "CurveLpTokenLiquidatorNoRegistry"
        );
      }
    }

    {
      address threeBrlAddress = 0x27b5Fc5333246F63280dA8e3e533512EfA747c13;
      (address addr, ) = ap.redemptionStrategies(threeBrlAddress);
      if (addr == address(0)) {
        vm.prank(ap.owner());
        ap.setRedemptionStrategy(
          threeBrlAddress,
          address(curveLpTokenLiquidatorNoRegistry),
          "CurveLpTokenLiquidatorNoRegistry"
        );
      }
    }

    {
      address wbnbUsdcCakeAddress = 0xd99c7F6C65857AC913a8f880A4cb84032AB2FC5b;
      (address addr, ) = ap.redemptionStrategies(wbnbUsdcCakeAddress);
      if (addr == address(0)) {
        vm.prank(ap.owner());
        ap.setRedemptionStrategy(wbnbUsdcCakeAddress, address(uniswapV2Liquidator), "UniswapV2Liquidator");
      }
    }

    {
      address busdWbnbCakeAddress = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
      (address addr, ) = ap.redemptionStrategies(busdWbnbCakeAddress);
      if (addr == address(0)) {
        vm.prank(ap.owner());
        ap.setRedemptionStrategy(busdWbnbCakeAddress, address(uniswapV2Liquidator), "UniswapV2Liquidator");
      }
    }

    {
      address jBrl = 0x316622977073BBC3dF32E7d2A9B3c77596a0a603;
      (address addr, ) = ap.redemptionStrategies(jBrl);
      if (addr == address(0)) {
        vm.prank(ap.owner());
        ap.setRedemptionStrategy(jBrl, address(jarvisLiquidator), "JarvisLiquidatorFunder");
      }
    }
  }

  // TODO remove after the next deploy configures the AP accordingly
  function configureCurveSwapPools() internal {
    curveSwapLiquidator = new CurveSwapLiquidator();

    for (uint8 i = 0; i < curveSwapPools.length; i++) {
      (address addr, ) = ap.redemptionStrategies(curveSwapPools[i].pool);
      if (addr == address(0)) {
        // TODO add the curve swap pools to the AP redemptionStrategies
        vm.prank(ap.owner());
        ap.setRedemptionStrategy(curveSwapPools[i].pool, address(curveSwapLiquidator), "CurveSwapLiquidator");
      }
    }
  }

  function testAnyLiquidation(uint256 random) internal {
    vm.assume(random > 100 && random < type(uint64).max);
    doTestAnyLiquidation(random);
  }

  struct LiquidationData {
    FusePoolDirectory.FusePool[] pools;
    address[] cTokens;
    IRedemptionStrategy[] strategies;
    bytes[] redemptionDatas;
    CTokenInterface[] markets;
    address[] borrowers;
    FuseSafeLiquidator liquidator;
    IFundsConversionStrategy[] fundingStrategies;
    bytes[] fundingDatas;
    CErc20Delegate debtMarket;
    CErc20Delegate collateralMarket;
    Comptroller comptroller;
    address borrower;
    uint256 borrowAmount;
    address flashSwapFundingToken;
    IUniswapV2Pair flashSwapPair;
  }

  function getPoolAndBorrower(uint256 random, LiquidationData memory vars)
    internal
    view
    returns (Comptroller, address)
  {
    if (vars.pools.length == 0) revert("no pools to pick from");

    uint256 i = random % vars.pools.length; // random pool
    Comptroller comptroller = Comptroller(vars.pools[i].comptroller);
    address[] memory borrowers = comptroller.getAllBorrowers();

    if (borrowers.length == 0) {
      return (Comptroller(address(0)), address(0));
    } else {
      uint256 k = random % borrowers.length; // random borrower
      address borrower = borrowers[k];

      return (comptroller, borrower);
    }
  }

  function setUpDebtAndCollateralMarkets(uint256 random, LiquidationData memory vars)
    internal
    returns (
      CErc20Delegate debt,
      CErc20Delegate collateral,
      uint256 borrowAmount
    )
  {
    // debt
    for (uint256 m = 0; m < vars.markets.length; m++) {
      uint256 marketIndexWithOffset = (random + m) % vars.markets.length;
      borrowAmount = vars.markets[marketIndexWithOffset].borrowBalanceStored(vars.borrower);
      if (borrowAmount > 0) {
        debt = CErc20Delegate(address(vars.markets[marketIndexWithOffset]));
        break;
      }
    }

    if (address(debt) != address(0)) {
      emit log("debt market is");
      emit log_address(address(debt));

      uint256 shortfall = 0;
      // reduce the collateral for each market of the borrower
      // until there is shortfall for which to be liquidated
      for (uint256 m = 0; m < vars.markets.length; m++) {
        uint256 marketIndexWithOffset = (random - m) % vars.markets.length;
        if (vars.markets[marketIndexWithOffset].balanceOf(vars.borrower) > 0) {
          if (address(vars.markets[marketIndexWithOffset]) == address(debt)) continue;

          collateral = CErc20Delegate(address(vars.markets[marketIndexWithOffset]));

          // the collateral prices change
          MasterPriceOracle mpo = MasterPriceOracle(address(vars.comptroller.oracle()));
          uint256 priceCollateral = mpo.getUnderlyingPrice(ICToken(address(collateral)));
          vm.mockCall(
            address(mpo),
            abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, ICToken(address(collateral))),
            abi.encode(priceCollateral / 5)
          );

          (, , shortfall) = vars.comptroller.getHypotheticalAccountLiquidity(vars.borrower, address(0), 0, 0);
          if (shortfall == 0) {
            emit log("collateral still enough");
            continue;
          } else {
            emit log("has shortfall");
            break;
          }
        }
      }
      if (shortfall == 0) {
        return (CErc20Delegate(address(0)), CErc20Delegate(address(0)), 0);
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

        if (address(vars.debtMarket) != address(0) && address(vars.collateralMarket) != address(0)) {
          emit log("found testable markets at random number");
          emit log_uint(random);
          break;
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
        emit log("debt token");
        emit log_address(debtTokenToFund);
        if (i++ > 10) revert("endless loop bad");

        (address addr, string memory strategyContract) = ap.fundingStrategies(debtTokenToFund);
        if (addr == address(0)) break;

        debtTokenToFund = addFundingStrategy(vars, debtTokenToFund, strategyContract);
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
        (address addr, string memory contractInterface) = ap.redemptionStrategies(collateralTokenToRedeem);
        if (addr == address(0)) break;
        collateralTokenToRedeem = addRedemptionStrategy(
          vars,
          IRedemptionStrategy(addr),
          contractInterface,
          collateralTokenToRedeem
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
          vars.borrowAmount / 100, //repayAmount,
          ICErc20(address(vars.debtMarket)),
          ICErc20(address(vars.collateralMarket)),
          vars.flashSwapPair,
          0,
          exchangeCollateralTo,
          IUniswapV2Router02(uniswapRouter),
          IUniswapV2Router02(uniswapRouter),
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

  function toggleFlashSwapPair(LiquidationData memory vars) internal {
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
    address inputToken
  ) internal returns (address) {
    bytes memory strategyData;
    address outputToken;

    if (compareStrings(strategyContract, "JarvisLiquidatorFunder")) {
      // TODO use already deployed strategies when they are redeployed
      strategy = jarvisLiquidator;
      (address syntheticToken, address collateralToken, address liquidityPool, uint256 expirationTime) = ap.jarvisPools(
        inputToken
      );
      outputToken = collateralToken;
      strategyData = abi.encode(syntheticToken, liquidityPool, expirationTime);
    } else if (compareStrings(strategyContract, "CurveSwapLiquidator")) {
      // TODO use already deployed strategies when they are redeployed
      strategy = curveSwapLiquidator;

      int128 outputIndex;
      int128 inputIndex;

      for (uint8 i = 0; i < curveSwapPools.length; i++) {
        CurveSwapPool memory csp = curveSwapPools[i];
        if (csp.pool == inputToken) {
          outputIndex = csp.preferredCoin;
          inputIndex = csp.preferredCoin == 0 ? int128(1) : int128(0);
          ICurvePool curvePool = ICurvePool(csp.pool);
          outputToken = curvePool.coins(outputIndex == 0 ? 0 : 1);
          break;
        }
      }

      strategyData = abi.encode(inputToken, inputIndex, outputIndex, outputToken, ap.getAddress("wtoken"));
    } else if (compareStrings(strategyContract, "UniswapV2Liquidator")) {
      // TODO use already deployed strategies when they are redeployed
      strategy = uniswapV2Liquidator;

      IUniswapV2Pair pair = IUniswapV2Pair(inputToken);
      address[] memory swapToken0Path;
      address[] memory swapToken1Path;

      if (pair.token0() == ap.getAddress("wtoken")) {
        swapToken0Path = new address[](0);
        swapToken1Path = new address[](2);

        swapToken1Path[0] = pair.token1();
        swapToken1Path[1] = pair.token0();
      } else {
        swapToken0Path = new address[](2);
        swapToken1Path = new address[](0);

        swapToken0Path[0] = pair.token0();
        swapToken0Path[1] = pair.token1();
      }

      strategyData = abi.encode(uniswapRouter, swapToken0Path, swapToken1Path);

      if (address(vars.flashSwapPair) == address(pair)) {
        emit log("toggling the flashswap pair");
        emit log_address(address(pair));
        toggleFlashSwapPair(vars);
      }

      outputToken = ap.getAddress("wtoken");
    } else if (compareStrings(strategyContract, "CurveLpTokenLiquidatorNoRegistry")) {
      // TODO use already deployed strategies when they are redeployed
      strategy = curveLpTokenLiquidatorNoRegistry;

      address wtoken = ap.getAddress("wtoken");
      address stable = ap.getAddress("usd");
      address wbtc = ap.getAddress("wBTCToken");

      address preferredToken = curveOracle.underlyingTokens(inputToken, 0);
      uint8 outputTokenIndex = 0;

      uint8 i = 0;
      while (true) {
        try curveOracle.underlyingTokens(inputToken, i) returns (address underlying) {
          if (underlying == wtoken) {
            preferredToken = wtoken;
            outputTokenIndex = i;
            break;
          } else if (underlying == stable) {
            preferredToken = stable;
            outputTokenIndex = i;
          } else if (preferredToken == address(0) && underlying == wbtc) {
            preferredToken = wbtc;
            outputTokenIndex = i;
          }
        } catch {
          break;
        }
        i++;
      }

      // TODO use curveOracle.getUnderlyingTokens()
      //      address[] memory underlyingTokens = curveOracle.getUnderlyingTokens(inputToken);
      //
      //      (preferredToken, outputTokenIndex) = pickPreferredToken(underlyingTokens);
      outputToken = preferredToken;
      strategyData = abi.encode(outputTokenIndex, outputToken, ap.getAddress("wtoken"), address(curveOracle));
    } else {
      revert("unknown collateral");
    }

    vars.liquidator._whitelistRedemptionStrategy(strategy, true);
    redemptionStrategies.push(strategy);
    redemptionDatas.push(strategyData);

    return outputToken;
  }

  function pickPreferredToken(address[] memory tokens) internal returns (address, uint8) {
    for (uint8 i = 0; i < tokens.length; i++) {
      if (tokens[i] == ap.getAddress("wtoken")) return (ap.getAddress("wtoken"), i);
    }
    for (uint8 i = 0; i < tokens.length; i++) {
      if (tokens[i] == ap.getAddress("usd")) return (ap.getAddress("usd"), i);
    }
    for (uint8 i = 0; i < tokens.length; i++) {
      if (tokens[i] == ap.getAddress("wBTCToken")) return (ap.getAddress("wBTCToken"), i);
    }
    return (tokens[0], 0);
  }

  function addFundingStrategy(
    LiquidationData memory vars,
    address debtToken,
    string memory strategyContract
  ) internal returns (address) {
    if (compareStrings(strategyContract, "JarvisLiquidatorFunder")) {
      (, address collateralToken, address liquidityPool, uint256 expirationTime) = ap.jarvisPools(debtToken);

      // TODO use already deployed strategies when they are redeployed
      IFundsConversionStrategy strategy = new JarvisLiquidatorFunder();
      vars.liquidator._whitelistRedemptionStrategy(strategy, true);
      fundingStrategies.push(strategy);

      bytes memory strategyData = abi.encode(collateralToken, liquidityPool, expirationTime);
      fundingDatas.push(strategyData);
      // } else if (compareStrings(strategyContract, "SomeOtherFunder")) {
      // bytes memory strategyData = abi.encode(strategySpecificParams);
      // (IERC20Upgradeable inputToken, uint256 inputAmount) = IFundsConversionStrategy(addr).estimateInputAmount(10**(debtToken.decimals()), strategyData);
      // fundingStrategies.push(new SomeOtherFunder());
      // return inputToken;
      return collateralToken;
    } else {
      revert("unknown debt token");
    }
  }
}
