// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { FuseSafeLiquidator } from "../FuseSafeLiquidator.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { ICurvePool } from "../external/curve/ICurvePool.sol";
import { CurveSwapLiquidatorFunder } from "../liquidators/CurveSwapLiquidatorFunder.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { IFundsConversionStrategy } from "../liquidators/IFundsConversionStrategy.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";
import { IUniswapV2Router02 } from "../external/uniswap/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../external/uniswap/IUniswapV2Pair.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

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

  function useThisToTestLiquidations() public fork(POLYGON_MAINNET) {
    address borrower = 0xA4F4406D3dc6482dB1397d0ad260fd223C8F37FC;
    address poolAddr = 0xD265ff7e5487E9DD556a4BB900ccA6D087Eb3AD2;
    address debtMarketAddr = 0x456b363D3dA38d3823Ce2e1955362bBd761B324b;
    address collateralMarketAddr = 0x28D0d45e593764C4cE88ccD1C033d0E2e8cE9aF3;

    FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars memory vars;
    vars.borrower = borrower;
    vars.cErc20 = ICErc20(debtMarketAddr);
    vars.cTokenCollateral = ICErc20(collateralMarketAddr);
    vars.repayAmount = 70565471214557927746795;
    vars.flashSwapPair = IUniswapV2Pair(0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827);
    vars.minProfitAmount = 0;
    vars.exchangeProfitTo = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    vars.uniswapV2RouterForBorrow = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    vars.uniswapV2RouterForCollateral = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    vars.redemptionStrategies = new IRedemptionStrategy[](0);
    vars.strategyData = new bytes[](0);
    vars.ethToCoinbase = 0;
    vars.debtFundingStrategies = new IFundsConversionStrategy[](1);
    vars.debtFundingStrategiesData = new bytes[](1);

    vars.debtFundingStrategies[0] = IFundsConversionStrategy(0x98110E8482E4e286716AC0671438BDd84C4D838c);
    vars.debtFundingStrategiesData[
        0
      ] = hex"0000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa84174000000000000000000000000aec757bf73cc1f4609a1459205835dd40b4e3f290000000000000000000000000000000000000000000000000000000000000960";

    // fsl.safeLiquidateToTokensWithFlashLoan(vars);

    vars.cErc20.comptroller();
  }

  // TODO test with marginal shortfall for liquidation penalty errors
}
