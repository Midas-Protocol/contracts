// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MidasSafeLiquidator } from "../MidasSafeLiquidator.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { IFundsConversionStrategy } from "../liquidators/IFundsConversionStrategy.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";
import { IUniswapV2Router02 } from "../external/uniswap/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../external/uniswap/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "../external/uniswap/IUniswapV2Factory.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { UniswapV2Liquidator } from "../liquidators/UniswapV2Liquidator.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract MidasSafeLiquidatorTest is BaseTest {
  MidasSafeLiquidator msl;
  address uniswapRouter;
  IUniswapV2Factory uniswapV2Factory;
  MasterPriceOracle mpo;

  function afterForkSetUp() internal override {
    uniswapV2Factory = IUniswapV2Factory(ap.getAddress("IUniswapV2Factory"));
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    if (block.chainid == BSC_MAINNET) {
      uniswapRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
      msl = new MidasSafeLiquidator();
      msl.initialize(
        ap.getAddress("wtoken"),
        uniswapRouter,
        ap.getAddress("stableToken"),
        ap.getAddress("wBTCToken"),
        "0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5",
        25
      );
    } else if (block.chainid == POLYGON_MAINNET) {
      uniswapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
      msl = MidasSafeLiquidator(payable(0x401B9E407896d5CAad75b057EF32Fa005c07252d));
      //      msl = new MidasSafeLiquidator();
      //      msl.initialize(
      //        ap.getAddress("wtoken"),
      //        uniswapRouter,
      //        ap.getAddress("stableToken"),
      //        ap.getAddress("wBTCToken"),
      //        "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f",
      //        30
      //      );
    }
  }

  function testLiquidateAndTakeDebtPosition() public debuggingOnly fork(POLYGON_MAINNET) {
    uint256 additionalCollateralRequired = 0;
    MidasSafeLiquidator.LiquidateAndTakeDebtPositionVars memory vars;

    address usdcAddress = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    vars.borrower = 0xA4F4406D3dc6482dB1397d0ad260fd223C8F37FC;
    vars.repayAmount = 52648061919138038486382;
    vars.debtMarket = ICErc20(0x456b363D3dA38d3823Ce2e1955362bBd761B324b); // jJPY
    vars.collateralMarket = ICErc20(0x28D0d45e593764C4cE88ccD1C033d0E2e8cE9aF3); // MAI
    vars.stableCollateralMarket = ICErc20(0x9b38995CA2CEe8e49144b98d09BE9dC3fFA0BE8E); // WMATIC market

    address wmatic = vars.stableCollateralMarket.underlying();

    // WMATIC-USDC
    vars.flashSwapPair = IUniswapV2Pair(uniswapV2Factory.getPair(wmatic, usdcAddress));
    (vars.fundingAmount, additionalCollateralRequired) = estimateFundingAmount(
      vars.debtMarket,
      vars.repayAmount,
      vars.stableCollateralMarket
    );

    vars.minProfitAmount = 0;
    vars.exchangeProfitTo = address(0);

    vars.uniswapV2RouterForBorrow = IUniswapV2Router02(uniswapRouter);
    vars.uniswapV2RouterForCollateral = IUniswapV2Router02(uniswapRouter);

    // use redemption strategy for MAI -> USDC
    // USDC is then repaid on the non-borrow side of the flashloan (from the WMATIC-USDC pair)
    vars.redemptionStrategies = new IRedemptionStrategy[](1);
    vars.redemptionStrategies[0] = UniswapV2Liquidator(0xd0CE13FD52b4bE9e375EAEf5B2d4F6dB207c0E90);
    //msl._whitelistRedemptionStrategy(vars.redemptionStrategies[0], true);

    vars.redemptionStrategiesData = new bytes[](1);
    address[] memory swapPath = new address[](2);
    swapPath[0] = vars.collateralMarket.underlying();
    swapPath[1] = usdcAddress;
    vars.redemptionStrategiesData[0] = abi.encode(uniswapRouter, swapPath);

    vars.ethToCoinbase = 0;

    vars.collateralFundingStrategies = new IFundsConversionStrategy[](0);
    vars.collateralFundingStrategiesData = new bytes[](0);

    vm.startPrank(msl.owner());
    // first deposit the additional collateral required in order to keep the debt position afloat
    if (additionalCollateralRequired > 0) {
      IERC20Upgradeable stableCollateralAsset = IERC20Upgradeable(wmatic);
      uint256 currentAllowance = stableCollateralAsset.allowance(msl.owner(), address(msl));
      if (currentAllowance < additionalCollateralRequired) {
        //        vm.prank(address(stableCollateralAsset)); // whale funding
        //        stableCollateralAsset.transfer(address(this), vars.fundingAmount);
        stableCollateralAsset.approve(address(msl), additionalCollateralRequired);
      } else {
        emit log("no additional allowance needed");
      }
    }

    msl.liquidateAndTakeDebtPosition(vars);
    vm.stopPrank();
  }

  function estimateFundingAmount(
    ICErc20 debtMarket,
    uint256 debtAmount,
    ICErc20 stableCollateralMarket
  ) internal view returns (uint256, uint256) {
    uint256 debtAssetPrice = mpo.getUnderlyingPrice(ICToken(address(debtMarket)));
    uint256 stableCollateralAssetPrice = mpo.getUnderlyingPrice(ICToken(address(stableCollateralMarket)));

    uint256 overcollateralizaionFactor = 2500; // 25%
    uint256 percent100 = 10000; // 100.00%

    uint256 debtValue = (debtAmount * debtAssetPrice) / 1e18; // decimals are accounted for by getUnderlyingPrice
    uint256 stableCollateralEquivalent = (debtValue * 1e18) / stableCollateralAssetPrice; // 18 + 18 - (36 - stableAsset.decimals)

    uint256 additionalCollateralRequired = (stableCollateralEquivalent * overcollateralizaionFactor) / percent100;
    return (stableCollateralEquivalent, additionalCollateralRequired);
  }
}
