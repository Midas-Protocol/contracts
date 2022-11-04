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

  // ctokens seized 10738741294254050199
  // WBNB flash swapped 5551528605298770
  // BUSD seized 1873003268211131735


  // TODO test with marginal shortfall for liquidation penalty errors
}
