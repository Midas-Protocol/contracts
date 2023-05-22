// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";

import "../midas/levered/LeveredPosition.sol";
import "../midas/levered/LeveredPositionFactory.sol";
import "../liquidators/JarvisLiquidatorFunder.sol";
import "../liquidators/SolidlySwapLiquidator.sol";
import "../liquidators/BalancerLinearPoolTokenLiquidator.sol";
import "../liquidators/AlgebraSwapLiquidator.sol";
import "../liquidators/registry/LiquidatorsRegistry.sol";
import "../liquidators/registry/LiquidatorsRegistryExtension.sol";
import "../liquidators/registry/ILiquidatorsRegistry.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import "../liquidators/CurveSwapLiquidator.sol";

abstract contract LeveredPositionTest is MarketsTest {
  ICErc20 collateralMarket;
  ICErc20 stableMarket;
  LeveredPositionFactory factory;
  LiquidatorsRegistry registry;
  LeveredPosition position;

  function afterForkSetUp() internal virtual override {
    super.afterForkSetUp();

    uint256 blocksPerYear;
    if (block.chainid == BSC_MAINNET) {
      blocksPerYear = 20 * 24 * 365 * 60;
      vm.prank(ap.owner());
      ap.setAddress("chainConfig.chainAddresses.ALGEBRA_SWAP_ROUTER", 0x327Dd3208f0bCF590A66110aCB6e5e6941A4EfA0);
    } else if (block.chainid == POLYGON_MAINNET) {
      blocksPerYear = 26 * 24 * 365 * 60;
    }

    if (block.chainid == BSC_CHAPEL) {
      registry = LiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));
      factory = LeveredPositionFactory(ap.getAddress("LeveredPositionFactory"));
    } else {
      // create and configure the liquidators registry
      registry = new LiquidatorsRegistry(ap);
      LiquidatorsRegistryExtension ext = new LiquidatorsRegistryExtension();
      registry._registerExtension(ext, DiamondExtension(address(0)));

      // create and initialize the levered positions factory
      LeveredPositionFactory impl = new LeveredPositionFactory();
      TransparentUpgradeableProxy factoryProxy = new TransparentUpgradeableProxy(
        address(impl),
        ap.getAddress("DefaultProxyAdmin"),
        ""
      );
      factory = LeveredPositionFactory(address(factoryProxy));
      factory.initialize(
        IFuseFeeDistributor(payable(address(ap.getAddress("FuseFeeDistributor")))),
        ILiquidatorsRegistry(address(registry)),
        blocksPerYear
      );
    }
  }

  function upgradePoolAndMarkets() internal {
    _upgradeExistingPool(collateralMarket.comptroller());
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
    factory._setPairWhitelisted(collateralMarket, stableMarket, true);
  }

  function _fundMarketAndSelf(ICErc20 market, address whale) internal {
    IERC20Upgradeable token = IERC20Upgradeable(market.underlying());
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

  function _configureTwoWayLiquidator(
    address inputMarket,
    address outputMarket,
    IRedemptionStrategy strategy
  ) internal {
    _configureLiquidator(inputMarket, outputMarket, strategy);
    _configureLiquidator(outputMarket, inputMarket, strategy);
  }

  function _configureLiquidator(
    address inputMarket,
    address outputMarket,
    IRedemptionStrategy strategy
  ) internal {
    IERC20Upgradeable inputToken = IERC20Upgradeable(ICErc20(inputMarket).underlying());
    IERC20Upgradeable outputToken = IERC20Upgradeable(ICErc20(outputMarket).underlying());
    registry.asExtension()._setRedemptionStrategy(strategy, inputToken, outputToken);
    registry.asExtension()._setRedemptionStrategy(strategy, outputToken, inputToken);
  }

  function _configureLiquidators(
    IERC20Upgradeable[] memory inputTokens,
    IERC20Upgradeable[] memory outputTokens,
    IRedemptionStrategy[] memory strategies
  ) internal {
    registry.asExtension()._setRedemptionStrategies(strategies, inputTokens, outputTokens);
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

  function testOpenLeveredPosition() public whenForking {
    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1e18, 1e4, "initial leverage ratio should be 1.0 (1e18)");
  }

  function testAnyLeverageRatio(uint64 ratioDiff) public whenForking {
    // ratioDiff is between 0 and 2^64 ~= 18.446e18
    uint256 minRatioDiff = position.getMinLeverageRatioDiff();
    emit log_named_uint("min ratio diff", minRatioDiff);
    vm.assume(minRatioDiff < ratioDiff);
    uint256 targetLeverageRatio = 1.03e18 + uint256(ratioDiff);

    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max lev ratio", maxRatio);
    vm.assume(targetLeverageRatio < maxRatio);

    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("base collateral", position.baseCollateral());
    assertApproxEqAbs(leverageRatioRealized, targetLeverageRatio, 1e4, "target ratio not matching");
  }

  function testMinMaxLeverageRatio() public whenForking {
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max ratio", maxRatio);
    uint256 minRatioDiff = position.getMinLeverageRatioDiff();
    emit log_named_uint("min ratio diff", minRatioDiff);

    assertGt(maxRatio, minRatioDiff, "max ratio <= min ratio diff");

    uint256 currentRatio = position.getCurrentLeverageRatio();
    vm.expectRevert("borrow stable failed");
    // 10% off for the swaps slippage accounting
    position.adjustLeverageRatio(currentRatio + ((90 * minRatioDiff) / 100));
    position.adjustLeverageRatio(currentRatio + minRatioDiff);
  }

  function testMaxLeverageRatio() public whenForking {
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max ratio", maxRatio);
    uint256 minRatioDiff = position.getMinLeverageRatioDiff();
    emit log_named_uint("min ratio diff", minRatioDiff);
    position.adjustLeverageRatio(maxRatio);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), maxRatio, 1e4, "target max ratio not matching");
  }

  function testLeverMaxDown() public whenForking {
    uint256 maxRatio = position.getMaxLeverageRatio();
    uint256 leverageRatioRealized = position.adjustLeverageRatio(maxRatio);
    assertApproxEqAbs(leverageRatioRealized, maxRatio, 1e4, "target ratio not matching");

    uint256 minRatioDiff = position.getMinLeverageRatioDiff();
    emit log_named_uint("min ratio diff", minRatioDiff);

    // decrease the ratio in 10 equal steps
    uint256 ratioDiffStep = (maxRatio - 1e18) / 9;
    while (leverageRatioRealized > 1e18) {
      uint256 targetLeverDownRatio = leverageRatioRealized - ratioDiffStep;
      if (targetLeverDownRatio - 1e18 < minRatioDiff) targetLeverDownRatio = 1e18;
      leverageRatioRealized = position.adjustLeverageRatio(targetLeverDownRatio);
      assertApproxEqAbs(leverageRatioRealized, targetLeverDownRatio, 1e4, "target lever down ratio not matching");
    }

    uint256 withdrawAmount = position.closePosition();
    emit log_named_uint("withdraw amount", withdrawAmount);

    assertEq(position.baseCollateral(), 0, "!nonzero base collateral");
    assertEq(position.getCurrentLeverageRatio(), 0, "!nonzero leverage ratio");
  }

  function asArray(IERC20Upgradeable t0, IERC20Upgradeable t1) internal returns (IERC20Upgradeable[] memory arr) {
    arr = new IERC20Upgradeable[](2);
    arr[0] = t0;
    arr[1] = t1;
  }

  function asArray(IRedemptionStrategy r0, IRedemptionStrategy r1) internal returns (IRedemptionStrategy[] memory arr) {
    arr = new IRedemptionStrategy[](2);
    arr[0] = r0;
    arr[1] = r1;
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

    // TODO set up in the deploy script
    vm.prank(ap.owner());
    ap.setAddress("chainConfig.chainAddresses.SOLIDLY_SWAP_ROUTER", 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109);

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

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

interface TwoBrl {
  function minter() external view returns (address);

  function mint(address payable _to, uint256 _value) external returns (bool);
}

//contract Jbrl2BrlLeveredPositionTest is LeveredPositionTest {
//  function setUp() public fork(BSC_MAINNET) {}
//
//  function afterForkSetUp() internal override {
//    super.afterForkSetUp();
//
//    uint256 depositAmount = 1000e18;
//
//    address twoBrlMarket = 0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba; // 2brl as collateral
//    address jBrlMarket = 0x82A3103bc306293227B756f7554AfAeE82F8ab7a; // jbrl as borrowable
//    address payable twoBrlWhale = payable(address(177)); // empty account
//    address jBrlWhale = 0xA0695f78AF837F570bcc50f53e58Cda300798B65; // solidly pair BRZ-JBRL
//    address brzToken = 0x71be881e9C5d4465B3FfF61e89c6f3651E69B5bb;
//
//    TwoBrl twoBrl = TwoBrl(ICErc20(twoBrlMarket).underlying());
//    vm.prank(twoBrl.minter());
//    twoBrl.mint(twoBrlWhale, depositAmount * 100);
//
//    CurveSwapLiquidator swapLiquidator = new CurveSwapLiquidator();
//    CurveLpTokenLiquidatorNoRegistry lpTokenLiquidator = new CurveLpTokenLiquidatorNoRegistry();
//    _configurePair(twoBrlMarket, jBrlMarket);
//    _configureLiquidator(twoBrlMarket, jBrlMarket, lpTokenLiquidator);
//    _configureLiquidator(jBrlMarket, twoBrlMarket, swapLiquidator);
//
//    IERC20Upgradeable jbrl = IERC20Upgradeable(ICErc20(jBrlMarket).underlying());
//    IERC20Upgradeable twobrl = IERC20Upgradeable(ICErc20(twoBrlMarket).underlying());
//    IERC20Upgradeable brz = IERC20Upgradeable(brzToken);
//
//    _configureLiquidators(asArray());
//
//    _fundMarketAndSelf(ICErc20(twoBrlMarket), twoBrlWhale);
//    _fundMarketAndSelf(ICErc20(jBrlMarket), jBrlWhale);
//
//    position = _openLeveredPosition(address(this), depositAmount);
//  }
//}

/*
contract XYLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(X_CHAIN_ID) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 1e18;

    address xMarket = 0x...1;
    address yMarket = 0x...2;
    address xWhale = 0x...3;

    IRedemptionStrategy liquidator = new IRedemptionStrategy();
    _configurePair(xMarket, yMarket, liquidator);
    _fundMarketAndSelf(ICErc20(xMarket), xWhale);
    _fundMarketAndSelf(ICErc20(yMarket), yWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}
*/
