// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "./config/BaseTest.t.sol";
import "../FuseSafeLiquidator.sol";

import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
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

      // TODO comment to test the on-chain FSL
      fsl = new FuseSafeLiquidator();
      fsl.initialize(
        ap.getAddress("wtoken"),
        uniswapRouter,
        ap.getAddress("stableToken"),
        ap.getAddress("wBTCToken"),
        "0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5",
        25
      );
    } else if (block.chainid == POLYGON_MAINNET) {
      uniswapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    }
  }

  function testBsc() public forkAtBlock(BSC_MAINNET, 20238373) {
    testWhitelistRevert();
    testWhitelist();
    testUpgrade();
  }

  function testPolygon() public forkAtBlock(POLYGON_MAINNET, 33063212) {
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

  function test41stkBnbLiquidation() public forkAtBlock(BSC_MAINNET, 22687943) {
    ICErc20 debtMarket = ICErc20(0x3Af258d24EBdC03127ED6cEb8e58cA90835fbca5);
    ICErc20 collateralMarket = ICErc20(0xAcfbf93d8fD1A9869bAb2328669dDba33296a421);
    address borrower = 0x2a2aaFf28425dDB0eD915A505378934b63D99907;

    address comp = debtMarket.comptroller();
    IComptroller comptroller = IComptroller(comp);
    MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
    uint256 initialPrice = mpo.getUnderlyingPrice(collateralMarket);
    uint256 priceCollateral = initialPrice;

    // decrease the collateral price by 1% until the position becomes liquidatable
    while (priceCollateral > (initialPrice * 9) / 10) {
      (uint256 err, uint256 liquidity, uint256 shortfall) = comptroller.getHypotheticalAccountLiquidity(
        borrower,
        address(0),
        0,
        0
      );

      emit log("liquidity");
      emit log_uint(liquidity);
      emit log("shortfall");
      emit log_uint(shortfall);

      if (shortfall > 0) {
        fsl.safeLiquidateToTokensWithFlashLoan(
          FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
            borrower,
            41590343090471371755,
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

      // decrease the collateral price by 1%
      priceCollateral = mpo.getUnderlyingPrice(collateralMarket);
      vm.mockCall(
        address(mpo),
        abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, collateralMarket),
        abi.encode((priceCollateral * 99) / 100)
      );
    }
  }
}
