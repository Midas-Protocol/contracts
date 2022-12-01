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

  struct LiquidationData {
    ICErc20 debtMarket;
    ICErc20 collateralMarket;
    address outputToken;
    uint256 repayAmount;
    IRedemptionStrategy[] redemptionStrategies;
    bytes[] redemptionStrategyData;
    IFundsConversionStrategy[] debtFundingStrategies;
    bytes[] debtFundingData;
    address borrower;
    uint256 borrowAmount;
  }

  function testMoonbeamLiquidation() public fork(MOONBEAM_MAINNET) {
    address xcDotAddress = 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080; // 0
    IERC20Upgradeable xcDot = IERC20Upgradeable(xcDotAddress);

    LiquidationData memory vars;
    vars.borrower = 0xd63dA94c6A7E8d15F8eed6D008815fD9e978CC1f;
    vars.repayAmount = 4274713836238;
    vars.debtMarket = ICErc20(0xa9736bA05de1213145F688e4619E5A7e0dcf4C72);
    vars.collateralMarket = ICErc20(0xb3D83F2CAb787adcB99d4c768f1Eb42c8734b563);
    IUniswapV2Pair pair = IUniswapV2Pair(0xd8FbdeF502770832E90a6352b275f20F38269b74);

    address exchangeTo = 0xAcc15dC74880C9944775448304B263D191c6077F;

    IUniswapV2Router02 router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    vm.mockCall(xcDotAddress, hex"313ce567", abi.encode(10));

    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.transfer.selector, 0x2fCa24E19C67070467927DDB85810fF766423e8e, 4274713836238),
      abi.encode(true)
    );
    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.balanceOf.selector, 0x2fCa24E19C67070467927DDB85810fF766423e8e),
      abi.encode(4274713836238)
    );
    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.approve.selector, 0xa9736bA05de1213145F688e4619E5A7e0dcf4C72, 4274713836238),
      abi.encode(true)
    );
    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.balanceOf.selector, 0xa9736bA05de1213145F688e4619E5A7e0dcf4C72),
      abi.encode(4274713836238)
    );

    fsl.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        vars.borrower,
        vars.repayAmount,
        vars.debtMarket,
        vars.collateralMarket,
        pair,
        0,
        exchangeTo,
        router,
        router,
        vars.redemptionStrategies,
        vars.redemptionStrategyData,
        0,
        vars.debtFundingStrategies,
        vars.debtFundingData
      )
    );
  }

  struct LiquidationData {
    ICErc20 debtMarket;
    ICErc20 collateralMarket;
    address outputToken;
    uint256 repayAmount;
    IRedemptionStrategy[] redemptionStrategies;
    bytes[] redemptionStrategyData;
    IFundsConversionStrategy[] debtFundingStrategies;
    bytes[] debtFundingData;
    address borrower;
    uint256 borrowAmount;
  }

  function testMoonbeamLiquidationTwo() public fork(MOONBEAM_MAINNET) {
    address xcDotAddress = 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080; // 0
    IERC20Upgradeable xcDot = IERC20Upgradeable(xcDotAddress);

    LiquidationData memory vars;
    vars.borrower = 0xB6526C5eb36369BAfAd8C58818CaCC09844144Fb;
    vars.repayAmount = 4003410624827;
    vars.debtMarket = ICErc20(0xa9736bA05de1213145F688e4619E5A7e0dcf4C72);
    vars.collateralMarket = ICErc20(0xb3D83F2CAb787adcB99d4c768f1Eb42c8734b563);
    IUniswapV2Pair pair = IUniswapV2Pair(0xd8FbdeF502770832E90a6352b275f20F38269b74);

    address exchangeTo = 0xAcc15dC74880C9944775448304B263D191c6077F;

    IUniswapV2Router02 router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    vm.mockCall(xcDotAddress, hex"313ce567", abi.encode(10));

    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.transfer.selector, 0x2fCa24E19C67070467927DDB85810fF766423e8e, 4274713836238),
      abi.encode(true)
    );
    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.balanceOf.selector, 0x2fCa24E19C67070467927DDB85810fF766423e8e),
      abi.encode(4003410624827)
    );
    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.approve.selector, 0xa9736bA05de1213145F688e4619E5A7e0dcf4C72, 4274713836238),
      abi.encode(true)
    );
    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.balanceOf.selector, 0xa9736bA05de1213145F688e4619E5A7e0dcf4C72),
      abi.encode(4003410624827)
    );

    fsl.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        vars.borrower,
        vars.repayAmount,
        vars.debtMarket,
        vars.collateralMarket,
        pair,
        0,
        exchangeTo,
        router,
        router,
        vars.redemptionStrategies,
        vars.redemptionStrategyData,
        0,
        vars.debtFundingStrategies,
        vars.debtFundingData
      )
    );
  }

  // TODO test with marginal shortfall for liquidation penalty errors
}
