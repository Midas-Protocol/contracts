// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";
import "../../liquidators/SolidlyLiquidator.sol";

contract SolidlyLiquidatorTest is BaseTest {
  SolidlyLiquidator public liquidator;
  address solidlySwapRouter = 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109;
  address hayAddress = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
  address busdAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address ankrAddress = 0xf307910A4c7bbc79691fD374889b36d8531B08e3;
  uint256 inputAmount = 1e18;

  function afterForkSetUp() internal override {
    liquidator = new SolidlyLiquidator();
  }

  function testSolidlyHayBusd() public fork(BSC_MAINNET) {
    address hayWhale = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;

    IERC20Upgradeable hay = IERC20Upgradeable(hayAddress);
    vm.prank(hayWhale);
    hay.transfer(address(liquidator), 1e18);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      hay,
      inputAmount,
      abi.encode(solidlySwapRouter, busdAddress, true)
    );

    assertEq(address(outputToken), busdAddress, "!busd output");
    assertApproxEqRel(outputAmount, inputAmount, 8e16, "!busd amount");
  }

  function testSolidlyAnkrHay() public fork(BSC_MAINNET) {
    address ankrWhale = 0x146eE71e057e6B10eFB93AEdf631Fde6CbAED5E2;

    IERC20Upgradeable ankr = IERC20Upgradeable(ankrAddress);
    vm.prank(ankrWhale);
    ankr.transfer(address(liquidator), 1e18);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      ankr,
      inputAmount,
      abi.encode(solidlySwapRouter, hayAddress, false)
    );

    assertEq(address(outputToken), hayAddress, "!hay output");
    assertApproxEqRel(outputAmount, inputAmount, 8e16, "!hay amount");
  }
}
