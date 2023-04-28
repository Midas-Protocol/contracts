// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import "../../liquidators/SolidlyLiquidator.sol";

contract SolidlyLiquidatorTest is BaseTest {
  SolidlyLiquidator public liquidator;
  MasterPriceOracle public mpo;
  address stable;
  address solidlySwapRouter = 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109;
  address hayAddress = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
  address ankrAddress = 0xf307910A4c7bbc79691fD374889b36d8531B08e3;
  uint256 inputAmount = 1e18;

  function afterForkSetUp() internal override {
    liquidator = new SolidlyLiquidator();
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    stable = ap.getAddress("stableToken");
  }

  function testSolidlyHayBusd() public fork(BSC_MAINNET) {
    address hayWhale = 0x1fa71DF4b344ffa5755726Ea7a9a56fbbEe0D38b;

    IERC20Upgradeable hay = IERC20Upgradeable(hayAddress);
    vm.prank(hayWhale);
    hay.transfer(address(liquidator), 1e18);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      hay,
      inputAmount,
      abi.encode(solidlySwapRouter, stable, true)
    );

    assertEq(address(outputToken), stable, "!busd output");
    assertApproxEqRel(inputAmount, outputAmount, 8e16, "!busd amount");
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

    uint256 outputValue = mpo.price(hayAddress) * outputAmount;
    uint256 inputValue = mpo.price(ankrAddress) * inputAmount;

    assertEq(address(outputToken), hayAddress, "!hay output");
    assertApproxEqRel(outputValue, inputValue, 8e16, "!hay amount");
  }
}
