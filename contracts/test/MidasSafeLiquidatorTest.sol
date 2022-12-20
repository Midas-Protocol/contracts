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
      msl = new MidasSafeLiquidator();
      msl.initialize(
        ap.getAddress("wtoken"),
        uniswapRouter,
        ap.getAddress("stableToken"),
        ap.getAddress("wBTCToken"),
        "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f",
        30
      );
    }
  }

  function testLiquidateAndTakeDebtPosition() public debuggingOnly fork(POLYGON_MAINNET) {
    MidasSafeLiquidator.LiquidateAndTakeDebtPositionVars memory vars;

    vars.borrower = 0xA4F4406D3dc6482dB1397d0ad260fd223C8F37FC;
    vars.repayAmount = 70646047191675691672694;
    vars.debtMarket = ICErc20(0x456b363D3dA38d3823Ce2e1955362bBd761B324b); // jJPY
    vars.collateralMarket = ICErc20(0x28D0d45e593764C4cE88ccD1C033d0E2e8cE9aF3); // MAI
    vars.stableCollateralMarket = ICErc20(0x9b38995CA2CEe8e49144b98d09BE9dC3fFA0BE8E); // WMATIC market

    vars.flashSwapPair = findFlashSwapPair(vars.collateralMarket, vars.stableCollateralMarket);
    vars.fundingAmount = estimateFundingAmount(vars.debtMarket, vars.repayAmount, vars.stableCollateralMarket);
    vars.minProfitAmount = 0;
    vars.exchangeProfitTo = address(0);

    vars.uniswapV2RouterForBorrow = IUniswapV2Router02(uniswapRouter);
    vars.uniswapV2RouterForCollateral = IUniswapV2Router02(uniswapRouter);

    vars.redemptionStrategies = new IRedemptionStrategy[](0);
    vars.redemptionStrategiesData = new bytes[](0);

    vars.ethToCoinbase = 0;

    vars.collateralFundingStrategies = new IFundsConversionStrategy[](0);
    vars.collateralFundingStrategiesData = new bytes[](0);

    IComptroller pool = IComptroller(vars.debtMarket.comptroller());
    address[] memory markets = new address[](3);
    markets[0] = address(vars.debtMarket);
    markets[1] = address(vars.collateralMarket);
    markets[2] = address(vars.stableCollateralMarket);
    pool.enterMarkets(markets);

    msl.liquidateAndTakeDebtPosition(vars);
  }

  function estimateFundingAmount(ICErc20 debtMarket, uint256 debtAmount, ICErc20 stableCollateralMarket) internal returns (uint256) {
    uint256 debtAssetPrice = mpo.getUnderlyingPrice(ICToken(address(debtMarket)));
    uint256 stableCollateralAssetPrice = mpo.getUnderlyingPrice(ICToken(address(stableCollateralMarket)));

    uint256 overcollateralizaionFactor = 3; // provide collateral value for 2x the debt value

    uint256 debtValue = (debtAmount * debtAssetPrice) / 1e18; // decimals are accounted for by getUnderlyingPrice
    uint256 stableCollateralEquivalent = (debtValue * 1e18) / stableCollateralAssetPrice; // 18 + 18 - (36 - stableAsset.decimals)
    uint256 stableCollateralRequired = stableCollateralEquivalent * overcollateralizaionFactor;
    return stableCollateralRequired;
  }

  function findFlashSwapPair(ICErc20 collateralMarket, ICErc20 stableCollateralMarket) internal returns (IUniswapV2Pair) {
    address userCollateral = collateralMarket.underlying();
    address liquidatorCollateral = stableCollateralMarket.underlying();
    return IUniswapV2Pair(uniswapV2Factory.getPair(userCollateral, liquidatorCollateral));
  }
}
