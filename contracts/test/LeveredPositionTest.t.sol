// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";
import { Unitroller } from "../compound/Unitroller.sol";

import "../midas/levered/LeveredPosition.sol";
import { AddressesProvider } from "../midas/AddressesProvider.sol";
import "../external/algebra/IAlgebraFactory.sol";
import "../midas/levered/LeveredPositionFactory.sol";

import "../liquidators/JarvisLiquidatorFunder.sol";
import "../liquidators/SolidlySwapLiquidator.sol";
import "../liquidators/CurveSwapLiquidator.sol";
import "../liquidators/BalancerLpTokenLiquidator.sol";
import "../liquidators/BalancerSwapLiquidator.sol";
import "../liquidators/registry/LiquidatorsRegistry.sol";
import "../liquidators/registry/LiquidatorsRegistryExtension.sol";
import "../liquidators/registry/ILiquidatorsRegistry.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract LeveredPositionTest is MarketsTest {
  ICErc20 collateralMarket;
  ICErc20 stableMarket;
  LeveredPositionFactory factory;
  LiquidatorsRegistry registry;

  function afterForkSetUp() internal override virtual {
    super.afterForkSetUp();

    uint256 blocksPerYear;
    if (block.chainid == BSC_MAINNET) {
      blocksPerYear = 20 * 24 * 365 * 60;
    }

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

  function upgradePoolAndMarkets() internal {
    _upgradeExistingPool(collateralMarket.comptroller());
    _upgradeMarket(CErc20Delegate(address(collateralMarket)));
    _upgradeMarket(CErc20Delegate(address(stableMarket)));
  }

  function _configurePair(
    address _colllat,
    address _stable,
    IRedemptionStrategy _liquidator,
    address _whale
  ) internal {
    collateralMarket = ICErc20(_colllat);
    stableMarket = ICErc20(_stable);
    upgradePoolAndMarkets();
    factory._setPairWhitelisted(collateralMarket, stableMarket, true);

    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    IERC20Upgradeable stableToken = IERC20Upgradeable(stableMarket.underlying());
    registry._setRedemptionStrategy(_liquidator, collateralToken, stableToken);
    registry._setRedemptionStrategy(_liquidator, stableToken, collateralToken);

    uint256 someTokens = collateralToken.balanceOf(_whale) / 10;
    vm.prank(_whale);
    collateralToken.transfer(address(this), someTokens);
  }

  function _openLeveredPosition(address positionOwner, uint256 depositAmount)
  internal
  returns (LeveredPosition position)
  {
    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    collateralToken.transfer(positionOwner, depositAmount);

    vm.startPrank(positionOwner);
    collateralToken.approve(address(factory), depositAmount);
    position = factory.createAndFundPosition(collateralMarket, stableMarket, collateralToken, depositAmount);
    vm.stopPrank();
  }

  function testOpenHayAnkrLeveredPosition() public {
    LeveredPosition position = _openLeveredPosition(address(this), 10e18);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1e18, 1e4, "initial leverage ratio should be 1.0 (1e18)");
  }

  function testHayAnkrAnyLeverageRatio(uint64 ratioDiff) public {
    // ratioDiff is between 0 and 2^64 ~= 18.446e18
    uint256 targetLeverageRatio = 1.03e18 + uint256(ratioDiff);

    LeveredPosition position = _openLeveredPosition(address(this), 10e18);
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max lev ratio", maxRatio);
    vm.assume(targetLeverageRatio < maxRatio);

    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("base collateral", position.baseCollateral());
    assertApproxEqAbs(leverageRatioRealized, targetLeverageRatio, 1e4, "target ratio not matching");
  }

  function testHayAnkrMinMaxLeverageRatio() public {
    LeveredPosition position = _openLeveredPosition(address(this), 10e18);
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

  function testHayAnkrMaxLeverageRatio() public {
    LeveredPosition position = _openLeveredPosition(address(this), 10e18);
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max ratio", maxRatio);
    uint256 minRatioDiff = position.getMinLeverageRatioDiff();
    emit log_named_uint("min ratio diff", minRatioDiff);
    position.adjustLeverageRatio(maxRatio);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), maxRatio, 1e4, "target max ratio not matching");
  }

  function testHayAnkrLeverMaxDown() public {
    LeveredPosition position = _openLeveredPosition(address(this), 10e18);
    uint256 maxRatio = position.getMaxLeverageRatio();
    uint256 leverageRatioRealized = position.adjustLeverageRatio(maxRatio);
    assertApproxEqAbs(leverageRatioRealized, maxRatio, 1e4, "target ratio not matching");

    // decrease the ratio in 10 equal steps
    uint256 targetLeverDownRatio;
    uint256 ratioDiffStep = (maxRatio - 1e18) / 9;
    for (uint256 i = 0; i < 10; i++) {
      targetLeverDownRatio = leverageRatioRealized - ratioDiffStep;
      leverageRatioRealized = position.adjustLeverageRatio(targetLeverDownRatio);
      assertApproxEqAbs(leverageRatioRealized, targetLeverDownRatio, 1e4, "target lever down ratio not matching");
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

    address ankrBnbMarket = 0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa;
    address hayMarket = 0x10b6f851225c203eE74c369cE876BEB56379FCa3;
    address ankrBnbWhale = 0x366B523317Cc95B1a4D30b33f8637882825C5E23;

    // TODO set up in the deploy script
    vm.prank(ap.owner());
    ap.setAddress("chainConfig.chainAddresses.SOLIDLY_SWAP_ROUTER", 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109);

    SolidlySwapLiquidator solidlyLiquidator = new SolidlySwapLiquidator();
    _configurePair(ankrBnbMarket, hayMarket, solidlyLiquidator, ankrBnbWhale);
  }
}

contract WMaticStMaticLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    address wmaticMarket = 0x4017cd39950d1297BBd9713D939bC5d9c6F2Be53;
    address stmaticMarket = 0xc1B068007114dC0F14f322Ef201491717f3e52cD;
    address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;

    CurveSwapLiquidator csl = new CurveSwapLiquidator();
    _configurePair(wmaticMarket, stmaticMarket, csl, wmaticWhale);
  }
}

contract JbrlBusdLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

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
    _configurePair(jbrlMarket, busdMarket, liquidator, jbrlWhale);
  }
}

contract WmaticMaticXLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    address wmaticMarket = 0x9871E541C19258Cc05769181bBE1dA814958F5A8;
    address maticxMarket = 0x0db51E5255E44751b376738d8979D969AD70bff6;
    address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;

    BalancerSwapLiquidator lpTokenLiquidator = new BalancerSwapLiquidator();
    _configurePair(wmaticMarket, maticxMarket, lpTokenLiquidator, wmaticWhale);
  }
}

/*
contract XYLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(X_CHAIN_ID) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    address xMarket = 0x...1;
    address yMarket = 0x...2;
    address xWhale = 0x...3;

    IRedemptionStrategy liquidator = new IRedemptionStrategy();
    _configurePair(xMarket, yMarket, liquidator, xWhale);
  }
}
*/