// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MarketsTest, BaseTest, CErc20Delegate } from "./config/MarketsTest.t.sol";
import { DiamondBase, DiamondExtension } from "../midas/DiamondExtension.sol";

import { LeveredPosition } from "../midas/levered/LeveredPosition.sol";
import { LeveredPositionFactory, IFuseFeeDistributor } from "../midas/levered/LeveredPositionFactory.sol";
import { JarvisLiquidatorFunder } from "../liquidators/JarvisLiquidatorFunder.sol";
import { SolidlySwapLiquidator } from "../liquidators/SolidlySwapLiquidator.sol";
import { BalancerLinearPoolTokenLiquidator } from "../liquidators/BalancerLinearPoolTokenLiquidator.sol";
import { AlgebraSwapLiquidator } from "../liquidators/AlgebraSwapLiquidator.sol";
import { CurveLpTokenLiquidatorNoRegistry } from "../liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import { LeveredPositionFactoryExtension } from "../midas/levered/LeveredPositionFactoryExtension.sol";
import { ILeveredPositionFactory } from "../midas/levered/ILeveredPositionFactory.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { LeveredPositionsLens } from "../midas/levered/LeveredPositionsLens.sol";
import { LiquidatorsRegistry } from "../liquidators/registry/LiquidatorsRegistry.sol";
import { LiquidatorsRegistryExtension } from "../liquidators/registry/LiquidatorsRegistryExtension.sol";
import { ILiquidatorsRegistry } from "../liquidators/registry/ILiquidatorsRegistry.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";
import { MidasFlywheelLensRouter } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";
import { IComptroller } from "../compound/ComptrollerInterface.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract LeveredPositionLensTest is BaseTest {
  LeveredPositionsLens lens;
  ILeveredPositionFactory factory;

  function afterForkSetUp() internal override {
    factory = ILeveredPositionFactory(ap.getAddress("LeveredPositionFactory"));
    lens = LeveredPositionsLens(ap.getAddress("LeveredPositionsLens"));
  }

  function testLPLens() public debuggingOnly fork(BSC_CHAPEL) {
    _testLPLens();
  }

  function _testLPLens() internal {
    address[] memory positions;
    bool[] memory closed;
    (positions, closed) = factory.getPositionsByAccount(0xdc3d8A4ee43dDe6a4E92F0D7A749C8eBD921239b);

    //    address[] memory accounts = factory.getAccountsWithOpenPositions();
    //    for (uint256 i = 0; i < accounts.length; i++) {
    //      (positions, closed) = factory.getPositionsByAccount(accounts[i]);
    //      if (positions.length > 0) break;
    //    }

    uint256[] memory apys = new uint256[](positions.length);
    LeveredPosition[] memory pos = new LeveredPosition[](positions.length);
    for (uint256 j = 0; j < positions.length; j++) {
      apys[j] = 1e10;

      if (address(0) == positions[j]) revert("DEBA");
      pos[j] = LeveredPosition(positions[j]);
    }

    LeveredPositionsLens.PositionInfo[] memory infos = lens.getPositionsInfo(pos, apys);

    for (uint256 k = 0; k < infos.length; k++) {
      emit log_named_uint("positionSupplyAmount", infos[k].positionSupplyAmount);
      emit log_named_uint("positionValue", infos[k].positionValue);
      emit log_named_uint("debtAmount", infos[k].debtAmount);
      emit log_named_uint("debtValue", infos[k].debtValue);
      emit log_named_uint("equityValue", infos[k].equityValue);

      emit log_named_int("currentApy", infos[k].currentApy);

      emit log_named_uint("debtRatio", infos[k].debtRatio);
      emit log_named_uint("liquidationThreshold", infos[k].liquidationThreshold);
      emit log_named_uint("safetyBuffer", infos[k].safetyBuffer);

      emit log("");
    }
  }
}

contract LeveredPositionFactoryTest is BaseTest {
  ILeveredPositionFactory factory;
  LeveredPositionsLens lens;
  MasterPriceOracle mpo;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    factory = ILeveredPositionFactory(ap.getAddress("LeveredPositionFactory"));
    lens = new LeveredPositionsLens();
    lens.initialize(factory);
  }

  function testChapelViewFn() public debuggingOnly fork(BSC_CHAPEL) {
    (address[] memory pos, bool[] memory closed) = factory.getPositionsByAccount(
      0x27521eae4eE4153214CaDc3eCD703b9B0326C908
    );
  }

  function testChapelNetApy() public debuggingOnly fork(BSC_CHAPEL) {
    ICErc20 _stableMarket = ICErc20(0x5aF82b72E4fA372e69765DeAc2e1B06acCD8DE15); // DAI

    uint256 borrowRate = 5.2e16; // 5.2%
    vm.mockCall(
      address(_stableMarket),
      abi.encodeWithSelector(_stableMarket.borrowRatePerBlock.selector),
      abi.encode(borrowRate / factory.blocksPerYear())
    );

    LeveredPositionFactoryExtension newExt = new LeveredPositionFactoryExtension();

    DiamondBase asBase = DiamondBase(address(factory));
    address[] memory oldExts = asBase._listExtensions();
    DiamondExtension oldExt = DiamondExtension(address(0));
    if (oldExts.length > 0) oldExt = DiamondExtension(oldExts[0]);
    vm.prank(factory.owner());
    asBase._registerExtension(newExt, oldExt);

    uint256 _borrowRate = _stableMarket.borrowRatePerBlock() * factory.blocksPerYear();
    emit log_named_uint("_borrowRate", _borrowRate);

    int256 netApy = lens.getNetAPY(
      2.7e16, // 2.7%
      1e18, // supply amount
      ICErc20(0xfa60851E76728eb31EFeA660937cD535C887fDbD), // BOMB
      _stableMarket,
      2e18 // ratio
    );

    emit log_named_int("net apy", netApy);

    // boosted APY = 2x 2.7% = 5.4 % of the base collateral
    // borrow APR = 5.2%
    // diff = 5.4 - 5.2 = 0.2%
    assertApproxEqRel(netApy, 0.2e16, 1e12, "!net apy");
  }
}

abstract contract LeveredPositionTest is MarketsTest {
  ICErc20 collateralMarket;
  ICErc20 stableMarket;
  ILeveredPositionFactory factory;
  LiquidatorsRegistry registry;
  LeveredPosition position;
  LeveredPositionsLens lens;

  function afterForkSetUp() internal virtual override {
    super.afterForkSetUp();

    uint256 blocksPerYear;
    if (block.chainid == BSC_MAINNET) {
      blocksPerYear = 20 * 24 * 365 * 60;
      vm.prank(ap.owner());
      ap.setAddress("ALGEBRA_SWAP_ROUTER", 0x327Dd3208f0bCF590A66110aCB6e5e6941A4EfA0);
    } else if (block.chainid == POLYGON_MAINNET) {
      blocksPerYear = 26 * 24 * 365 * 60;
      vm.prank(ap.owner());
      ap.setAddress("SOLIDLY_SWAP_ROUTER", 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109);
    }

    if (block.chainid == BSC_CHAPEL) {
      registry = LiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));
      factory = ILeveredPositionFactory(ap.getAddress("LeveredPositionFactory"));
    } else {
      // create and configure the liquidators registry
      registry = new LiquidatorsRegistry(ap);
      LiquidatorsRegistryExtension ext = new LiquidatorsRegistryExtension();
      registry._registerExtension(ext, DiamondExtension(address(0)));

      // create and initialize the levered positions factory
      LeveredPositionFactoryExtension factoryExt = new LeveredPositionFactoryExtension();
      LeveredPositionFactory factoryBase = new LeveredPositionFactory(
        IFuseFeeDistributor(payable(address(ap.getAddress("FuseFeeDistributor")))),
        ILiquidatorsRegistry(address(registry)),
        blocksPerYear
      );
      factoryBase._registerExtension(factoryExt, LeveredPositionFactoryExtension(address(0)));
      factory = ILeveredPositionFactory(address(factoryBase));
    }
    lens = new LeveredPositionsLens();
    lens.initialize(factory);
  }

  function upgradePoolAndMarkets() internal {
    _upgradeExistingPool(address(collateralMarket.comptroller()));
    _upgradeMarket(CErc20Delegate(address(collateralMarket)));
    _upgradeMarket(CErc20Delegate(address(stableMarket)));
  }

  function _configurePairAndLiquidator(
    address _collat,
    address _stable,
    IRedemptionStrategy _liquidator
  ) internal {
    _configurePair(_collat, _stable);
    _configureTwoWayLiquidator(_collat, _stable, _liquidator);
  }

  function _configurePair(address _collat, address _stable) internal {
    collateralMarket = ICErc20(_collat);
    stableMarket = ICErc20(_stable);
    upgradePoolAndMarkets();
    vm.prank(factory.owner());
    factory._setPairWhitelisted(collateralMarket, stableMarket, true);
  }

  function _configureTwoWayLiquidator(
    address inputMarket,
    address outputMarket,
    IRedemptionStrategy strategy
  ) internal {
    IERC20Upgradeable inputToken = underlying(inputMarket);
    IERC20Upgradeable outputToken = underlying(outputMarket);
    vm.startPrank(registry.owner());
    registry.asExtension()._setRedemptionStrategy(strategy, inputToken, outputToken);
    registry.asExtension()._setRedemptionStrategy(strategy, outputToken, inputToken);
    vm.stopPrank();
  }

  function underlying(address market) internal view returns (IERC20Upgradeable) {
    return IERC20Upgradeable(ICErc20(market).underlying());
  }

  struct Liquidator {
    IERC20Upgradeable inputToken;
    IERC20Upgradeable outputToken;
    IRedemptionStrategy strategy;
  }

  function _configureMultipleLiquidators(Liquidator[] memory liquidators) internal {
    IRedemptionStrategy[] memory strategies = new IRedemptionStrategy[](liquidators.length);
    IERC20Upgradeable[] memory inputTokens = new IERC20Upgradeable[](liquidators.length);
    IERC20Upgradeable[] memory outputTokens = new IERC20Upgradeable[](liquidators.length);
    for (uint256 i = 0; i < liquidators.length; i++) {
      strategies[i] = liquidators[i].strategy;
      inputTokens[i] = liquidators[i].inputToken;
      outputTokens[i] = liquidators[i].outputToken;
    }
    vm.startPrank(registry.owner());
    registry.asExtension()._setRedemptionStrategies(strategies, inputTokens, outputTokens);
    vm.stopPrank();
  }

  function _fundMarketAndSelf(ICErc20 market, address whale) internal {
    IERC20Upgradeable token = IERC20Upgradeable(market.underlying());

    if (whale == address(0)) {
      whale = address(911);
      //vm.deal(address(token), whale, 100e18);
    }

    uint256 allTokens = token.balanceOf(whale);
    vm.prank(whale);
    token.transfer(address(this), allTokens / 20);

    if (market.getCash() < allTokens / 2) {
      vm.startPrank(whale);
      token.approve(address(market), allTokens / 2);
      market.mint(allTokens / 2);
      vm.stopPrank();
    }
  }

  function _openLeveredPosition(address _positionOwner, uint256 _depositAmount)
    internal
    returns (LeveredPosition _position)
  {
    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    collateralToken.transfer(_positionOwner, _depositAmount);

    vm.startPrank(_positionOwner);
    collateralToken.approve(address(factory), _depositAmount);
    _position = factory.createAndFundPosition(collateralMarket, stableMarket, collateralToken, _depositAmount);
    vm.stopPrank();
  }

  function testOpenLeveredPosition() public virtual whenForking {
    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1e18, 1e15, "initial leverage ratio should be 1.0 (1e18)");
  }

  function testAnyLeverageRatio(uint64 ratioDiff) public whenForking {
    // ratioDiff is between 0 and 2^64 ~= 18.446e18
    uint256 minRatio = position.getMinLeverageRatio();
    emit log_named_uint("min ratio", minRatio);
    uint256 targetLeverageRatio = 1e18 + uint256(ratioDiff);
    vm.assume(minRatio < targetLeverageRatio);

    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max lev ratio", maxRatio);
    vm.assume(targetLeverageRatio < maxRatio);

    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("base collateral", position.baseCollateral());
    assertApproxEqAbs(leverageRatioRealized, targetLeverageRatio, 1e15, "target ratio not matching");
  }

  function testMinMaxLeverageRatio() public whenForking {
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max ratio", maxRatio);
    uint256 minRatio = position.getMinLeverageRatio();
    emit log_named_uint("min ratio", minRatio);

    assertGt(maxRatio, minRatio, "max ratio <= min ratio");

    if (minRatio > 1e18) {
      vm.expectRevert(abi.encode(LeveredPosition.BorrowStableFailed.selector, 0x3fa));
      position.adjustLeverageRatio(minRatio - 1);
      position.adjustLeverageRatio(minRatio + 1);
    }
  }

  function testMaxLeverageRatio() public whenForking {
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max ratio", maxRatio);

    uint256 rate = lens.getBorrowRateAtRatio(collateralMarket, stableMarket, 1e18, maxRatio);
    emit log_named_uint("borrow rate at max ratio", rate);

    uint256 minRatio = position.getMinLeverageRatio();
    emit log_named_uint("min ratio", minRatio);
    position.adjustLeverageRatio(maxRatio);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), maxRatio, 1e15, "target max ratio not matching");
  }

  function testRewardsAccruedClaimed() public whenForking {
    address[] memory flywheels = position.pool().getRewardsDistributors();
    if (flywheels.length > 0) {
      vm.warp(block.timestamp + 60 * 60 * 24);
      vm.roll(block.number + 10000);

      (ERC20[] memory rewardTokens, uint256[] memory amounts) = position.getAccruedRewards();

      ERC20 rewardToken;
      bool atLeastOneAccrued = false;
      for (uint256 i = 0; i < amounts.length; i++) {
        atLeastOneAccrued = amounts[i] > 0;
        if (atLeastOneAccrued) {
          rewardToken = rewardTokens[i];
          emit log_named_address("accrued from reward token", address(rewardTokens[i]));
          break;
        }
      }

      assertEq(atLeastOneAccrued, true, "!should have accrued at least one reward token");

      if (atLeastOneAccrued) {
        uint256 rewardsBalanceBefore = rewardToken.balanceOf(address(this));
        position.claimRewards();
        uint256 rewardsBalanceAfter = rewardToken.balanceOf(address(this));
        assertGt(rewardsBalanceAfter - rewardsBalanceBefore, 0, "should have claimed some rewards");
      }
    } else {
      emit log("no flywheels/rewards for the pair pool");
    }
  }

  function testLeverMaxDown() public whenForking {
    uint256 maxRatio = position.getMaxLeverageRatio();
    uint256 leverageRatioRealized = position.adjustLeverageRatio(maxRatio);
    assertApproxEqAbs(leverageRatioRealized, maxRatio, 1e15, "target ratio not matching");

    uint256 minRatio = position.getMinLeverageRatio();
    emit log_named_uint("min ratio", minRatio);

    // decrease the ratio in 10 equal steps
    uint256 ratioDiffStep = (maxRatio - 1e18) / 9;
    while (leverageRatioRealized > 1e18) {
      uint256 targetLeverDownRatio = leverageRatioRealized - ratioDiffStep;
      if (targetLeverDownRatio - 1e18 < minRatio) targetLeverDownRatio = 1e18;
      leverageRatioRealized = position.adjustLeverageRatio(targetLeverDownRatio);
      assertApproxEqAbs(leverageRatioRealized, targetLeverDownRatio, 1e15, "target lever down ratio not matching");
    }

    uint256 withdrawAmount = position.closePosition();
    emit log_named_uint("withdraw amount", withdrawAmount);

    assertEq(position.baseCollateral(), 0, "!nonzero base collateral");
    assertEq(position.getCurrentLeverageRatio(), 0, "!nonzero leverage ratio");
  }
}

contract HayAnkrLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 10e18;

    address ankrBnbMarket = 0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa;
    address hayMarket = 0x10b6f851225c203eE74c369cE876BEB56379FCa3;
    address ankrBnbWhale = 0x366B523317Cc95B1a4D30b33f8637882825C5E23;

    SolidlySwapLiquidator solidlyLiquidator = new SolidlySwapLiquidator();
    _configurePairAndLiquidator(ankrBnbMarket, hayMarket, solidlyLiquidator);
    _fundMarketAndSelf(ICErc20(ankrBnbMarket), ankrBnbWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract WMaticStMaticLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 200e18;

    address wmaticMarket = 0x4017cd39950d1297BBd9713D939bC5d9c6F2Be53;
    address stmaticMarket = 0xc1B068007114dC0F14f322Ef201491717f3e52cD;
    address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    address stmaticWhale = 0x52997D5abC01e9BFDd29cccB183ffc60F6d6bF8c;

    BalancerLinearPoolTokenLiquidator linearSwapLiquidator = new BalancerLinearPoolTokenLiquidator();
    _configurePairAndLiquidator(wmaticMarket, stmaticMarket, linearSwapLiquidator);
    _fundMarketAndSelf(ICErc20(wmaticMarket), wmaticWhale);
    _fundMarketAndSelf(ICErc20(stmaticMarket), stmaticWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract JbrlBusdLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 2000e18;

    address jbrlMarket = 0x82A3103bc306293227B756f7554AfAeE82F8ab7a;
    address busdMarket = 0xa7213deB44f570646Ea955771Cc7f39B58841363;
    address jbrlWhale = 0xBe9E8Ec25866B21bA34e97b9393BCabBcB4A5C86;

    vm.startPrank(ap.owner());
    ap.setJarvisPool(
      ICErc20(jbrlMarket).underlying(), // syntheticToken
      ICErc20(busdMarket).underlying(), // collateralToken
      0x0fD8170Dc284CD558325029f6AEc1538c7d99f49, // liquidityPool
      60 * 40 // expirationTime
    );
    vm.stopPrank();

    JarvisLiquidatorFunder liquidator = new JarvisLiquidatorFunder();
    _configurePairAndLiquidator(jbrlMarket, busdMarket, liquidator);
    _fundMarketAndSelf(ICErc20(jbrlMarket), jbrlWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract WmaticMaticXLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 200e18;

    address wmaticMarket = 0x9871E541C19258Cc05769181bBE1dA814958F5A8;
    address maticxMarket = 0x0db51E5255E44751b376738d8979D969AD70bff6;
    address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    address maticxWhale = 0x72f0275444F2aF8dBf13F78D54A8D3aD7b6E68db;

    BalancerLinearPoolTokenLiquidator linearSwapLiquidator = new BalancerLinearPoolTokenLiquidator();
    _configurePairAndLiquidator(wmaticMarket, maticxMarket, linearSwapLiquidator);
    _fundMarketAndSelf(ICErc20(wmaticMarket), wmaticWhale);
    _fundMarketAndSelf(ICErc20(maticxMarket), maticxWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract StkBnbWBnbLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 2e18;

    address stkBnbMarket = 0xAcfbf93d8fD1A9869bAb2328669dDba33296a421;
    address wbnbMarket = 0x3Af258d24EBdC03127ED6cEb8e58cA90835fbca5;
    address stkBnbWhale = 0x84b78452A97C5afDa1400943333F691448069A29; // algebra pool
    address wbnbWhale = 0x84b78452A97C5afDa1400943333F691448069A29; // algebra pool

    AlgebraSwapLiquidator liquidator = new AlgebraSwapLiquidator();
    _configurePairAndLiquidator(stkBnbMarket, wbnbMarket, liquidator);
    _fundMarketAndSelf(ICErc20(stkBnbMarket), stkBnbWhale);
    _fundMarketAndSelf(ICErc20(wbnbMarket), wbnbWhale);

    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    collateralToken.transfer(address(this), depositAmount);
    collateralToken.approve(address(factory), depositAmount);
    position = factory.createAndFundPosition(collateralMarket, stableMarket, collateralToken, depositAmount);
  }
}

interface TwoBrl {
  function minter() external view returns (address);

  function mint(address payable _to, uint256 _value) external returns (bool);
}

contract Jbrl2BrlLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 1000e18;

    address twoBrlMarket = 0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba; // 2brl as collateral
    address jBrlMarket = 0x82A3103bc306293227B756f7554AfAeE82F8ab7a; // jbrl as borrowable
    address payable twoBrlWhale = payable(address(177)); // empty account
    address jBrlWhale = 0xA0695f78AF837F570bcc50f53e58Cda300798B65; // solidly pair BRZ-JBRL

    TwoBrl twoBrl = TwoBrl(ICErc20(twoBrlMarket).underlying());
    vm.prank(twoBrl.minter());
    twoBrl.mint(twoBrlWhale, depositAmount * 100);

    // TODO jBRL -> 2brl needs a reverse curve LP token liquidator
    CurveLpTokenLiquidatorNoRegistry lpTokenLiquidator = new CurveLpTokenLiquidatorNoRegistry();
    _configurePairAndLiquidator(twoBrlMarket, jBrlMarket, lpTokenLiquidator);
    _fundMarketAndSelf(ICErc20(twoBrlMarket), twoBrlWhale);
    _fundMarketAndSelf(ICErc20(jBrlMarket), jBrlWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract Par2EurLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 100e18;

    address twoEurMarket = 0x1944FA4a490f85Ed99e2c6fF9234F94DE16fdbde;
    address parMarket = 0xCA1A940B02E15FF71C128f877b29bdb739785299;
    address twoEurWhale = address(888);
    address balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address parWhale = 0xFa22D298E3b0bc1752E5ef2849cEc1149d596674; // uniswap pool

    IERC20Upgradeable twoEur = IERC20Upgradeable(ICErc20(twoEurMarket).underlying());
    vm.prank(balancer);
    twoEur.transfer(twoEurWhale, 80 * depositAmount);

    BalancerLinearPoolTokenLiquidator liquidator = new BalancerLinearPoolTokenLiquidator();
    _configurePairAndLiquidator(twoEurMarket, parMarket, liquidator);
    _fundMarketAndSelf(ICErc20(twoEurMarket), twoEurWhale);
    _fundMarketAndSelf(ICErc20(parMarket), parWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract MaticXMaticXBbaWMaticLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 1000e18;

    address maticXBbaWMaticMarket = 0x13e763D25D78c3Fd6FEA534231BdaEBE7Fa52945;
    address maticXMarket = 0x0db51E5255E44751b376738d8979D969AD70bff6;
    address maticXBbaWMaticWhale = 0xB0B28d7A74e62DF5F6F9E0d9Ae0f4e7982De9585;
    address maticXWhale = 0x72f0275444F2aF8dBf13F78D54A8D3aD7b6E68db;

    IComptroller pool = IComptroller(ICErc20(maticXBbaWMaticMarket).comptroller());
    _configurePairAndLiquidator(maticXBbaWMaticMarket, maticXMarket, new BalancerLinearPoolTokenLiquidator());

    {
      vm.prank(pool.admin());
      pool._supplyCapWhitelist(address(maticXBbaWMaticMarket), maticXBbaWMaticWhale, true);
    }

    _fundMarketAndSelf(ICErc20(maticXBbaWMaticMarket), maticXBbaWMaticWhale);
    _fundMarketAndSelf(ICErc20(maticXMarket), maticXWhale);

    position = _openLeveredPosition(address(this), depositAmount);

    {
      vm.prank(pool.admin());
      pool._supplyCapWhitelist(address(maticXBbaWMaticMarket), address(position), true);
    }
  }
}

contract BombTDaiLeveredPositionTest is LeveredPositionTest {
  uint256 depositAmount = 1e18;
  address whale = 0xe7B7dF67C1fe053f1C6B965826d3bFF19603c482;

  function setUp() public fork(BSC_CHAPEL) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    address xMarket = 0xfa60851E76728eb31EFeA660937cD535C887fDbD; // BOMB
    address yMarket = 0x5aF82b72E4fA372e69765DeAc2e1B06acCD8DE15; // tdai

    collateralMarket = ICErc20(xMarket);
    stableMarket = ICErc20(yMarket);

    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    vm.prank(whale);
    collateralToken.transfer(address(this), depositAmount);

    collateralToken.approve(address(factory), depositAmount);
    position = factory.createAndFundPositionAtRatio(
      collateralMarket,
      stableMarket,
      collateralToken,
      depositAmount,
      1.2e18
    );
  }

  function testOpenLeveredPosition() public override whenForking {
    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1.2e18, 1e15, "initial leverage ratio should be 1.2");
  }
}

/*
contract XYLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(X_CHAIN_ID) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 1e18;

    address xMarket = 0x...1;
    address yMarket = 0x...2;
    address xWhale = 0x...3;
    address yWhale = 0x...4;

    IRedemptionStrategy liquidator = new IRedemptionStrategy();
    _configurePairAndLiquidator(xMarket, yMarket, liquidator);
    _fundMarketAndSelf(ICErc20(xMarket), xWhale);
    _fundMarketAndSelf(ICErc20(yMarket), yWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}
*/
