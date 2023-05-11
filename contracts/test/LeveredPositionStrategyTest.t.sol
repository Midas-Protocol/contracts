// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";
import { Unitroller } from "../compound/Unitroller.sol";

import "../midas/levered/LeveredPosition.sol";
import { AddressesProvider } from "../midas/AddressesProvider.sol";
import "../liquidators/JarvisLiquidatorFunder.sol";
import "../liquidators/SolidlySwapLiquidator.sol";
import "../external/algebra/IAlgebraFactory.sol";
import "../midas/levered/LeveredPositionFactory.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LeveredPositionTest is MarketsTest {
  ICErc20 collateralMarket;
  ICErc20 stableMarket;
  LeveredPositionFactory factory;
  LiquidatorsRegistry registry;

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 blocksPerYear;
    if (block.chainid == BSC_MAINNET) {
      blocksPerYear = 20 * 24 * 365 * 60;
    }

    // create and configure the liquidators registry
    registry = new LiquidatorsRegistry(ap);

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
      registry,
      blocksPerYear
    );
  }

  function upgradePoolAndMarkets() internal {
    _upgradeExistingPool(collateralMarket.comptroller());
    _upgradeMarket(CErc20Delegate(address(collateralMarket)));
    _upgradeMarket(CErc20Delegate(address(stableMarket)));
  }

  function testJbrlBusdLeveredPosition() public debuggingOnly fork(BSC_MAINNET) {
    _configureJbrlBusdPair();
    LeveredPosition position = _openLeveredPosition(address(this), 1000e18);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1e18, 1e4, "initial leverage ratio should be 1.0 (1e18)");
    position.adjustLeverageRatio(1.5e18);
    emit log_named_uint("withdraw amount", position.closePosition());
  }

  function _configureJbrlBusdPair() internal {
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

    uint256 allTokens = collateralToken.balanceOf(_whale);
    vm.prank(_whale);
    collateralToken.transfer(address(this), allTokens);
  }

  function _configureHayAnkrPair() internal {
    address ankrBnbMarket = 0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa;
    address hayMarket = 0x10b6f851225c203eE74c369cE876BEB56379FCa3;
    address ankrBnbWhale = 0x366B523317Cc95B1a4D30b33f8637882825C5E23;
    SolidlySwapLiquidator solidlyLiquidator = new SolidlySwapLiquidator();
    _configurePair(ankrBnbMarket, hayMarket, solidlyLiquidator, ankrBnbWhale);
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

  function testOpenHayAnkrLeveredPosition() public fork(BSC_MAINNET) {
    _configureHayAnkrPair();
    _testOpenLeveredPosition();
  }

  function _testOpenLeveredPosition() internal {
    LeveredPosition position = _openLeveredPosition(address(this), 10e18);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1e18, 1e4, "initial leverage ratio should be 1.0 (1e18)");
  }

  function testHayAnkrAnyLeverageRatio(uint64 ratioDiff) public fork(BSC_MAINNET) {
    _configureHayAnkrPair();
    _testAnyLeverageRatio(ratioDiff);
  }

  function _testAnyLeverageRatio(uint64 ratioDiff) internal {
    // ratioDiff is between 0 and 2^64 ~= 18.446e18
    uint256 targetLeverageRatio = 1.03e18 + uint256(ratioDiff);

    _configureHayAnkrPair();
    LeveredPosition position = _openLeveredPosition(address(this), 10e18);
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max lev ratio", maxRatio);
    vm.assume(targetLeverageRatio < maxRatio);

    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("base collateral", position.baseCollateral());
    assertApproxEqAbs(leverageRatioRealized, targetLeverageRatio, 1e4, "target ratio not matching");
  }

  function testHayAnkrMinMaxLeverageRatio() public fork(BSC_MAINNET) {
    _configureHayAnkrPair();
    _testMinMaxLeverageRatio();
  }

  function _testMinMaxLeverageRatio() internal {
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

  function testHayAnkrMaxLeverageRatio() public fork(BSC_MAINNET) {
    _configureHayAnkrPair();
    _testMaxLeverageRatio();
  }

  function _testMaxLeverageRatio() internal {
    LeveredPosition position = _openLeveredPosition(address(this), 10e18);
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max ratio", maxRatio);
    uint256 minRatioDiff = position.getMinLeverageRatioDiff();
    emit log_named_uint("min ratio diff", minRatioDiff);
    position.adjustLeverageRatio(maxRatio);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), maxRatio, 1e4, "target max ratio not matching");
  }

  function testHayAnkrLeverMaxDown() public fork(BSC_MAINNET) {
    _configureHayAnkrPair();
    _testLeverMaxDown();
  }

  function _testLeverMaxDown() internal {
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
