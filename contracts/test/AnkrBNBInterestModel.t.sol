// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";

import { AnkrBNBInterestRateModel } from "../compound/AnkrBNBInterestRateModel.sol";

contract AnkrBNBInterestRateModelTest is BaseTest {
  AnkrBNBInterestRateModel interestRateModel;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    interestRateModel = new AnkrBNBInterestRateModel(
      10512000,
      25.6e15,
      3,
      0.8e18,
      0xBb1Aa6e59E5163D8722a122cd66EBA614b59df0d
    );
  }

  function testBorrowRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 borrowRate = interestRateModel.getBorrowRate(10e18, 2e18, 5e18);
    emit log_uint(borrowRate);
  }
}
