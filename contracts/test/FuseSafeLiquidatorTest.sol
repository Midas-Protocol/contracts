// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "./config/BaseTest.t.sol";
import "../FuseSafeLiquidator.sol";

import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { ICurvePool } from "../external/curve/ICurvePool.sol";
import { CurveSwapLiquidatorFunder } from "../liquidators/CurveSwapLiquidatorFunder.sol";
import { Comptroller } from "../compound/Comptroller.sol";

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

  function afterForkSetUp() internal override {
    fsl = FuseSafeLiquidator(payable(ap.getAddress("FuseSafeLiquidator")));
    if (block.chainid == BSC_MAINNET) {
      uniswapRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    } else if (block.chainid == POLYGON_MAINNET) {
      uniswapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    }
  }

  function testBsc() public fork(BSC_MAINNET) {
    testWhitelistRevert();
    testWhitelist();
    testUpgrade();
  }

  function testPolygon() public fork(POLYGON_MAINNET) {
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

  function testNonStrategyLiquidation() public fork(BSC_MAINNET) {
    ICErc20 debtMarket = ICErc20(0xFEc2B82337dC69C61195bCF43606f46E9cDD2930);
    ICErc20 collateralMarket = ICErc20(0x1f6B34d12301d6bf0b52Db7938Fc90ab4f12fE95);
    address borrower = 0x03092C07fa6a4AdBdf219081BEDEdf7006Dd6874;

    address comp = debtMarket.comptroller();
    IComptroller comptroller = IComptroller(comp);
    MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
    uint256 initialPrice = mpo.getUnderlyingPrice(collateralMarket);
    uint256 priceCollateral = initialPrice;

    fsl.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        borrower,
        5551528605298770,
        debtMarket,
        collateralMarket,
        IUniswapV2Pair(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16),
        0,
        0x0000000000000000000000000000000000000000,
        IUniswapV2Router02(uniswapRouter),
        IUniswapV2Router02(uniswapRouter),
        new IRedemptionStrategy[](0),
        new bytes[](0),
        0,
        new IFundsConversionStrategy[](0),
        new bytes[](0)
      )
    );
  }

  struct CurveStrategyData {
    ICErc20 debtMarket;
    ICErc20 collateralMarket;
    address outputToken;
    uint256 borrowedAmount;
    IFundsConversionStrategy[] debtFundingStrategies;
    CurveSwapLiquidatorFunder curveSwapLiquidatorFunder;
    IRedemptionStrategy[] redemptionStrategies;
    bytes[] redemptionStrategyData;
    ICurvePool curvePool;
    bytes[] debtFundingData;
    address borrower;
    uint256 borrowAmount;
  }

  function testCurveStrategyLiquidation() public fork(BSC_MAINNET) {
    CurveStrategyData memory vars;

    vars.borrower = 0x25bd0fC0e4597B4C9535d94876A8ca1F531Fa92e; // borrower

    vars.debtMarket = ICErc20(0x9b575BF2F6ca8bf8967Aa320D3AAe3Df82DD17Cd); // jCHF market
    vars.collateralMarket = ICErc20(0x383158Db17719d2Cf1Ce10Ccb9a6Dd7cC1f54EF3); // 3brl market

    vars.outputToken = vars.debtMarket.underlying(); // jCHF

    vars.curveSwapLiquidatorFunder = new CurveSwapLiquidatorFunder();

    // whitelist redemption strategy
    vm.prank(fsl.owner());
    fsl._whitelistRedemptionStrategy(IRedemptionStrategy(address(vars.curveSwapLiquidatorFunder)), true);

    vars.curvePool = ICurvePool(0xBcA6E25937B0F7E0FD8130076b6B218F595E32e2);

    {
      // debt funding strategy
      vars.debtFundingStrategies = new IFundsConversionStrategy[](1);
      vars.debtFundingStrategies[0] = IFundsConversionStrategy(address(vars.curveSwapLiquidatorFunder));

      // deb funding strategy data
      vars.debtFundingData = new bytes[](1);
      bytes memory strategyData = abi.encode(
        vars.curvePool, // curve pool address
        0, // curve pool input token (BUSD) index
        1, // curve pool output token (jCHF) index
        vars.outputToken, // jCHF
        ap.getAddress("wtoken")
      );
      vars.debtFundingData[0] = strategyData;

      // redemption strategy
      vars.redemptionStrategies = new IRedemptionStrategy[](2);
      vars.redemptionStrategies[0] = IRedemptionStrategy(0x8683557815883E9F9c4b79CF7DC034709A805d49);
      vars.redemptionStrategies[1] = IRedemptionStrategy(0xC01c0B84A3c2d8A181636BF2b892FD186758B721);

      // redemption strategy data
      vars.redemptionStrategyData = new bytes[](2);
      strategyData = abi.encode(
        0,
        0x316622977073BBC3dF32E7d2A9B3c77596a0a603, // jbrl
        ap.getAddress("wtoken"),
        0x4544d21EB5B368b3f8F98DcBd03f28aC0Cf6A0CA // oracle
      );
      vars.redemptionStrategyData[0] = strategyData;
      strategyData = abi.encode(
        0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
        0x0fD8170Dc284CD558325029f6AEc1538c7d99f49, // jBRL-BUSD liquidity pool,
        2400 // txExpirationPeriod
      );
      vars.redemptionStrategyData[1] = strategyData;

      // price manipulation for liquidate
      {
        address comp = vars.debtMarket.comptroller();
        IComptroller comptroller = IComptroller(comp);
        MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
        uint256 initialPrice = mpo.getUnderlyingPrice(vars.collateralMarket);
        uint256 priceCollateral = initialPrice;
        vm.mockCall(
          address(mpo),
          abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, vars.collateralMarket),
          abi.encode(initialPrice / 100)
        );
      }

      vars.borrowAmount = vars.debtMarket.borrowBalanceStored(vars.borrower);

      // liquidate
      fsl.safeLiquidateToTokensWithFlashLoan(
        FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
          vars.borrower, // borrower
          vars.borrowAmount / 100,
          vars.debtMarket,
          vars.collateralMarket,
          IUniswapV2Pair(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16),
          0,
          0x0000000000000000000000000000000000000000,
          IUniswapV2Router02(uniswapRouter),
          IUniswapV2Router02(uniswapRouter),
          vars.redemptionStrategies,
          vars.redemptionStrategyData,
          0,
          vars.debtFundingStrategies,
          vars.debtFundingData
        )
      );
    }
  }

  // ctokens seized 10738741294254050199
  // WBNB flash swapped 5551528605298770
  // BUSD seized 1873003268211131735

  // TODO test with marginal shortfall for liquidation penalty errors
}
