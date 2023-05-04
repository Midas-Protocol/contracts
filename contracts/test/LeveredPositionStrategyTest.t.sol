// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";
import { Unitroller } from "../compound/Unitroller.sol";

import "../midas/levered/LeveredPositionStrategy.sol";
import { AddressesProvider } from "../midas/AddressesProvider.sol";
import "../liquidators/JarvisLiquidatorFunder.sol";
import "../liquidators/SolidlySwapLiquidator.sol";
import "../external/algebra/IAlgebraFactory.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LeveredPositionStrategyTest is MarketsTest, ILeveredPositionFactory {
  ICErc20 collateralMarket;
  ICErc20 stableMarket;
  IFundsConversionStrategy jarvisFunder;
  IRedemptionStrategy solidlyLiquidator;

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    jarvisFunder = new JarvisLiquidatorFunder();
    solidlyLiquidator = new SolidlySwapLiquidator();
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

    LeveredPositionStrategy position = new LeveredPositionStrategy(positionOwner, collateralMarket, stableMarket);

    jBRL.approve(address(position), 1e36);

    position.fundPosition(IERC20Upgradeable(jBRLAddress), 1e22);
    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
    emit log_named_uint("max lev ratio", position.getMaxLeverageRatio());
    position.adjustLeverageRatio(2.5e18);
    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
    emit log_named_uint("withdraw amount", position.closePosition());
    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
  }

  function _openHayAnkrLeveredPosition(address positionOwner) internal returns (LeveredPositionStrategy position) {
    collateralMarket = ICErc20(0xb2b01D6f953A28ba6C8f9E22986f5bDDb7653aEa); // ankrBNB market
    stableMarket = ICErc20(0x10b6f851225c203eE74c369cE876BEB56379FCa3); // HAY market
    address ankrBnbWhale = 0x366B523317Cc95B1a4D30b33f8637882825C5E23;
    upgradePoolAndMarkets();

    IERC20Upgradeable ankrBnb = IERC20Upgradeable(collateralMarket.underlying());

    position = new LeveredPositionStrategy(positionOwner, collateralMarket, stableMarket);

    vm.prank(ankrBnbWhale);
    ankrBnb.transfer(positionOwner, 10e18);

    vm.startPrank(positionOwner);
    ankrBnb.approve(address(position), 1e36);
    position.fundPosition(ankrBnb, 10e18);
    vm.stopPrank();
  }

  function testOpenHayAnkrLeveredPosition() public fork(BSC_MAINNET) {
    LeveredPositionStrategy position = _openHayAnkrLeveredPosition(address(this));

    assertApproxEqAbs(position.getCurrentLeverageRatio(), 1e18, 1e4, "initial leverage ratio should be 1.0 (1e18)");

    emit log_named_uint("max lev ratio", position.getMaxLeverageRatio());
    //    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
    //    emit log_named_uint("close with FL", position.closePosition());
    //    emit log_named_uint("current ratio", position.getCurrentLeverageRatio());
    //
    //    emit log_named_uint("total deposits", collateralMarket.balanceOfUnderlyingHypo(address(position)));
    //    emit log_named_uint("base collateral", position.baseCollateral());
  }

  function testHayAnkr15LeverageRatio() public fork(BSC_MAINNET) {
    LeveredPositionStrategy position = _openHayAnkrLeveredPosition(address(this));
    uint256 targetLeverageRatio = 1.5e18;
    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("base collateral", position.baseCollateral());
    assertApproxEqAbs(leverageRatioRealized, targetLeverageRatio, 1e4, "target ratio not matching");
  }

  function testHayAnkrMaxLeverageRatio() public fork(BSC_MAINNET) {
    LeveredPositionStrategy position = _openHayAnkrLeveredPosition(address(this));
    uint256 targetLeverageRatio = position.getMaxLeverageRatio();
    // 5% slippage
    position.adjustLeverageRatio((targetLeverageRatio * 95) / 100);
    assertApproxEqAbs(position.getCurrentLeverageRatio(), targetLeverageRatio, 1e4, "target max ratio not matching");
  }

  function getRedemptionStrategy(IERC20Upgradeable fundingToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy strategy, bytes memory strategyData)
  {
    // hay/ankrBnb -> SolidlySwapLiquidator
    {
      address ankrBnb = 0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827; // token1
      address hay = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5; // token0
      bool hayAndAnkrBnb = address(fundingToken) == hay && address(outputToken) == ankrBnb;
      bool ankrBnbAndHay = address(fundingToken) == ankrBnb && address(outputToken) == hay;
      address pool = 0xC6dB38F34DA75393E9aac841c08104348997D509; // VolatileV1 AMM - HAY/ankrBNB
      address router = 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109;

      if (ankrBnbAndHay || hayAndAnkrBnb) {
        strategy = solidlyLiquidator;
        strategyData = abi.encode(router, outputToken, false);
      }
    }
  }

  function getFundingStrategy(IERC20Upgradeable fundingToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IFundsConversionStrategy fundingStrategy, bytes memory strategyData)
  {
    // JarvisLiquidatorFunder
    {
      AddressesProvider.JarvisPool[] memory pools = ap.getJarvisPools();
      for (uint256 i = 0; i < pools.length; i++) {
        AddressesProvider.JarvisPool memory pool = pools[i];
        if (pool.collateralToken == address(fundingToken)) {
          require(address(outputToken) == pool.syntheticToken, "!output token mismatch");
          strategyData = abi.encode(pool.collateralToken, pool.liquidityPool, pool.expirationTime);
          fundingStrategy = jarvisFunder;
          break;
        } else if (pool.syntheticToken == address(fundingToken)) {
          require(address(outputToken) == pool.collateralToken, "!output token mismatch");
          strategyData = abi.encode(pool.syntheticToken, pool.liquidityPool, pool.expirationTime);
          fundingStrategy = jarvisFunder;
          break;
        }
      }
    }
  }
}
