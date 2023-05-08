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
  IFundsConversionStrategy jarvisFunder;
  IRedemptionStrategy solidlyLiquidator;
  LeveredPositionFactory factory;

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    jarvisFunder = new JarvisLiquidatorFunder();
    LeveredPositionFactory impl = new LeveredPositionFactory();
    TransparentUpgradeableProxy factoryProxy = new TransparentUpgradeableProxy(
      address(impl),
      ap.getAddress("DefaultProxyAdmin"),
      ""
    );
    factory = LeveredPositionFactory(address(factoryProxy));
    factory.initialize(IFuseFeeDistributor(payable(address(ap.getAddress("FuseFeeDistributor")))));

    solidlyLiquidator = factory.solidlyLiquidator();
    IERC20Upgradeable ankrBnb = IERC20Upgradeable(0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827);
    IERC20Upgradeable hay = IERC20Upgradeable(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);
    factory._addRedemptionStrategy(solidlyLiquidator, ankrBnb, hay);
    factory._addRedemptionStrategy(solidlyLiquidator, hay, ankrBnb);
  }

  function upgradePoolAndMarkets() internal {
    _upgradeExistingPool(collateralMarket.comptroller());
    _upgradeMarket(CErc20Delegate(address(collateralMarket)));
    _upgradeMarket(CErc20Delegate(address(stableMarket)));
  }

  function testOpenLeveredPosition() public fork(BSC_MAINNET) {
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
    emit log_named_uint("max lev ratio", position.getMaxLeverageRatio());
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

    position = factory.createPosition(collateralMarket, stableMarket);

    vm.prank(ankrBnbWhale);
    ankrBnb.transfer(positionOwner, 10e18);

    vm.startPrank(positionOwner);
    ankrBnb.approve(address(position), 1e36);
    position.fundPosition(ankrBnb, 10e18);
    vm.stopPrank();
  }

  function testOpenHayAnkrLeveredPosition() public fork(BSC_MAINNET) {
    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));

    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1e18, 1e4, "initial leverage ratio should be 1.0 (1e18)");

    emit log_named_uint("min diff", position.getMinLeverageRatioDiff());
    emit log_named_uint("max lev ratio", position.getMaxLeverageRatio());
  }

  function testHayAnkrLeverUpDown() public fork(BSC_MAINNET) {
    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));
    uint256 targetLeverageRatio = 1.8e18;
    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("base collateral", position.baseCollateral());
    assertApproxEqAbs(leverageRatioRealized, targetLeverageRatio, 1e4, "target ratio not matching");

    uint256 targetDeleverRatio = 1.2e18;
    uint256 deleverageRatioRealized = position.adjustLeverageRatio(targetDeleverRatio);
    assertApproxEqAbs(deleverageRatioRealized, targetDeleverRatio, 1e4, "target delever ratio not matching");
  }

  function testHayAnkrAnyLeverageRatio(uint256 targetLeverageRatio) public fork(BSC_MAINNET) {
    vm.assume(targetLeverageRatio > 1.05e18 && targetLeverageRatio < 3e18);

    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));
    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("base collateral", position.baseCollateral());
    assertApproxEqAbs(leverageRatioRealized, targetLeverageRatio, 1e4, "target ratio not matching");
  }

  function testHayAnkrMaxLeverageRatio() public fork(BSC_MAINNET) {
    LeveredPosition position = _openHayAnkrLeveredPosition(address(this));
    uint256 targetLeverageRatio = position.getMaxLeverageRatio();
    position.adjustLeverageRatio(targetLeverageRatio);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), targetLeverageRatio, 1e4, "target max ratio not matching");
  }
}
