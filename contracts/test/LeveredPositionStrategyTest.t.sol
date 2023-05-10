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

    SolidlySwapLiquidator solidlyLiquidator = new SolidlySwapLiquidator();
    IERC20Upgradeable ankrBnb = IERC20Upgradeable(0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827);
    IERC20Upgradeable hay = IERC20Upgradeable(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);

    // create and configure the liquidators registry
    registry = new LiquidatorsRegistry();
    registry._setRedemptionStrategy(solidlyLiquidator, ankrBnb, hay);
    registry._setRedemptionStrategy(solidlyLiquidator, hay, ankrBnb);

    // create and initialize the levered positions factory
    LeveredPositionFactory impl = new LeveredPositionFactory();
    TransparentUpgradeableProxy factoryProxy = new TransparentUpgradeableProxy(
      address(impl),
      ap.getAddress("DefaultProxyAdmin"),
      ""
    );
    factory = LeveredPositionFactory(address(factoryProxy));
    factory.initialize(IFuseFeeDistributor(payable(address(ap.getAddress("FuseFeeDistributor")))), registry);
  }

  function upgradePoolAndMarkets() internal {
    _upgradeExistingPool(collateralMarket.comptroller());
    _upgradeMarket(CErc20Delegate(address(collateralMarket)));
    _upgradeMarket(CErc20Delegate(address(stableMarket)));
  }

  function testOpenLeveredPosition() public debuggingOnly fork(BSC_MAINNET) {
    collateralMarket = ICErc20(0x82A3103bc306293227B756f7554AfAeE82F8ab7a); // jBRL market
    stableMarket = ICErc20(0xa7213deB44f570646Ea955771Cc7f39B58841363); // bUSD market
    upgradePoolAndMarkets();
    factory._setPairWhitelisted(collateralMarket, stableMarket, true);

    vm.startPrank(ap.owner());
    ap.setJarvisPool(
      collateralMarket.underlying(), // syntheticToken
      stableMarket.underlying(), // collateralToken
      0x0fD8170Dc284CD558325029f6AEc1538c7d99f49, // liquidityPool
      60 * 40 // expirationTime
    );
    vm.stopPrank();

    address positionOwner = address(this);
    address jBRLAddress = collateralMarket.underlying();
    IERC20Upgradeable jBRL = IERC20Upgradeable(jBRLAddress);

    address jBRLWhale = 0xBe9E8Ec25866B21bA34e97b9393BCabBcB4A5C86;
    vm.prank(jBRLWhale);
    jBRL.transfer(positionOwner, 1e22);

    LeveredPosition position = factory.createPosition(collateralMarket, stableMarket);

    jBRL.approve(address(position), 1e36);

    position.fundPosition(IERC20Upgradeable(jBRLAddress), 1e22);
    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
    position.adjustLeverageRatio(2.5e18);
    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
    emit log_named_uint("withdraw amount", position.closePosition());
  }

  function _openHayAnkrLeveredPosition(address positionOwner) internal returns (LeveredPosition position) {
    collateralMarket = ICErc20(0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa); // ankrBNB market
    stableMarket = ICErc20(0x10b6f851225c203eE74c369cE876BEB56379FCa3); // HAY market
    address ankrBnbWhale = 0x366B523317Cc95B1a4D30b33f8637882825C5E23;
    upgradePoolAndMarkets();
    factory._setPairWhitelisted(collateralMarket, stableMarket, true);

    IERC20Upgradeable ankrBnb = IERC20Upgradeable(collateralMarket.underlying());

    vm.prank(ankrBnbWhale);
    ankrBnb.transfer(positionOwner, 10e18);

    vm.startPrank(positionOwner);
    ankrBnb.approve(address(factory), 1e36);
    position = factory.createAndFundPosition(collateralMarket, stableMarket, ankrBnb, 10e18);
    vm.stopPrank();
  }

  function testOpenHayAnkrLeveredPosition() public fork(BSC_MAINNET) {
    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));
    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1e18, 1e4, "initial leverage ratio should be 1.0 (1e18)");
  }

  function testHayAnkrAnyLeverageRatio(uint64 ratioDiff) public fork(BSC_MAINNET) {
    // ratioDiff is between 0 and 2^64 ~= 18.446e18
    uint256 targetLeverageRatio = 1.03e18 + uint256(ratioDiff);

    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max lev ratio", maxRatio);
    vm.assume(targetLeverageRatio < maxRatio);

    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("base collateral", position.baseCollateral());
    assertApproxEqAbs(leverageRatioRealized, targetLeverageRatio, 1e4, "target ratio not matching");
  }

  function testHayAnkrMinMaxLeverageRatio() public fork(BSC_MAINNET) {
    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));
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
    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));
    uint256 maxRatio = position.getMaxLeverageRatio();
    emit log_named_uint("max ratio", maxRatio);
    uint256 minRatioDiff = position.getMinLeverageRatioDiff();
    emit log_named_uint("min ratio diff", minRatioDiff);
    position.adjustLeverageRatio(maxRatio);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), maxRatio, 1e4, "target max ratio not matching");
  }

  function testHayAnkrLeverMaxDown() public fork(BSC_MAINNET) {
    uint256 leverageRatioRealized;
    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));
    uint256 maxRatio = position.getMaxLeverageRatio();
    leverageRatioRealized = position.adjustLeverageRatio(maxRatio);
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
