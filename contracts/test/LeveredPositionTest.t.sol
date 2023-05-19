// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";

import "../midas/levered/LeveredPosition.sol";
import "../midas/levered/LeveredPositionFactory.sol";
import "../liquidators/JarvisLiquidatorFunder.sol";
import "../liquidators/SolidlySwapLiquidator.sol";
import "../liquidators/BalancerLinearPoolTokenLiquidator.sol";
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
  uint256 depositAmount;
  LeveredPosition position;

  function afterForkSetUp() internal virtual override {
    super.afterForkSetUp();

    uint256 blocksPerYear;
    if (block.chainid == BSC_MAINNET) {
      blocksPerYear = 20 * 24 * 365 * 60;
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

  function _configurePair(
    address _collat,
    address _stable,
    IRedemptionStrategy _liquidator
  ) internal {
    _configurePair(_collat, _stable);

    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    IERC20Upgradeable stableToken = IERC20Upgradeable(stableMarket.underlying());
    _configureLiquidator(collateralToken, stableToken, _liquidator);
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

    if (token.balanceOf(address(market)) < allTokens / 2) {
      vm.startPrank(whale);
      token.approve(address(market), allTokens / 2);
      market.mint(allTokens / 2);
      vm.stopPrank();
    }
  }

  function _configureLiquidator(
    address inputMarket,
    address outputMarket,
    IRedemptionStrategy strategy
  ) internal {
    _configureLiquidator(ICErc20(inputMarket), ICErc20(outputMarket), strategy);
  }

  function _configureLiquidator(
    ICErc20 inputMarket,
    ICErc20 outputMarket,
    IRedemptionStrategy strategy
  ) internal {
    IERC20Upgradeable inputToken = IERC20Upgradeable(inputMarket.underlying());
    IERC20Upgradeable outputToken = IERC20Upgradeable(outputMarket.underlying());
    _configureLiquidator(inputToken, outputToken, strategy);
  }

  function _configureLiquidator(
    IERC20Upgradeable inputToken,
    IERC20Upgradeable outputToken,
    IRedemptionStrategy strategy
  ) internal {
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
}

contract HayAnkrLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    depositAmount = 10e18;

    address ankrBnbMarket = 0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa;
    address hayMarket = 0x10b6f851225c203eE74c369cE876BEB56379FCa3;
    address ankrBnbWhale = 0x366B523317Cc95B1a4D30b33f8637882825C5E23;

    // TODO set up in the deploy script
    vm.prank(ap.owner());
    ap.setAddress("chainConfig.chainAddresses.SOLIDLY_SWAP_ROUTER", 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109);

    SolidlySwapLiquidator solidlyLiquidator = new SolidlySwapLiquidator();
    _configurePair(ankrBnbMarket, hayMarket, solidlyLiquidator);
    _fundMarketAndSelf(ICErc20(ankrBnbMarket), ankrBnbWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract WMaticStMaticLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    depositAmount = 200e18;

    address wmaticMarket = 0x4017cd39950d1297BBd9713D939bC5d9c6F2Be53;
    address stmaticMarket = 0xc1B068007114dC0F14f322Ef201491717f3e52cD;
    address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    address stmaticWhale = 0x52997D5abC01e9BFDd29cccB183ffc60F6d6bF8c;

    _configurePair(wmaticMarket, stmaticMarket);
    _fundMarketAndSelf(ICErc20(wmaticMarket), wmaticWhale);
    _fundMarketAndSelf(ICErc20(stmaticMarket), stmaticWhale);

    BalancerLinearPoolTokenLiquidator linearSwapLiquidator = new BalancerLinearPoolTokenLiquidator();
    _configureLiquidator(wmaticMarket, stmaticMarket, linearSwapLiquidator);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract JbrlBusdLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    depositAmount = 2000e18;

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
    _configurePair(jbrlMarket, busdMarket, liquidator);
    _fundMarketAndSelf(ICErc20(jbrlMarket), jbrlWhale);

    position = _openLeveredPosition(address(this), depositAmount);
  }
}

contract WmaticMaticXLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    depositAmount = 200e18;

    address wmaticMarket = 0x9871E541C19258Cc05769181bBE1dA814958F5A8;
    address maticxMarket = 0x0db51E5255E44751b376738d8979D969AD70bff6;
    address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    address maticxWhale = 0x72f0275444F2aF8dBf13F78D54A8D3aD7b6E68db;

    BalancerLinearPoolTokenLiquidator linearSwapLiquidator = new BalancerLinearPoolTokenLiquidator();
    _configurePair(wmaticMarket, maticxMarket, linearSwapLiquidator);
    _fundMarketAndSelf(ICErc20(wmaticMarket), wmaticWhale);
    _fundMarketAndSelf(ICErc20(maticxMarket), maticxWhale);

    position = _openLeveredPosition(address(this), depositAmount);
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
