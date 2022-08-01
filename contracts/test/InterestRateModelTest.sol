// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";

import { AnkrBNBInterestRateModel } from "../compound/AnkrBNBInterestRateModel.sol";
import { JumpRateModel } from "../compound/JumpRateModel.sol";
import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";

contract InterestRateModeLest is BaseTest {
  AnkrBNBInterestRateModel ankrBnbInterestRateModel;
  JumpRateModel jumpRateModel;
  WhitePaperInterestRateModel whitepaperInterestRateModel;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    ankrBnbInterestRateModel = new AnkrBNBInterestRateModel(
      10512000,
      0.256e17,
      0.64e17,
      0.8e18,
      3,
      0xBb1Aa6e59E5163D8722a122cd66EBA614b59df0d
    );
    jumpRateModel = new JumpRateModel(10512000, 0.2e17, 0.2e18, 2e18, 0.9e18);
    whitepaperInterestRateModel = new WhitePaperInterestRateModel(10512000, 0.2e17, 0.2e18);
  }

  function _convertToPerYear(uint256 value) internal returns (uint256) {
    return value * 10512000;
  }

  function testJumpRateBorrowRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 borrowRate = jumpRateModel.getBorrowRate(0, 0, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(1e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(2e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(3e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(4e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(5e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(6e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
  }

  function testJumpRateSupplyRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 supplyRate = jumpRateModel.getSupplyRate(0, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(10e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(20e18, 10e18, 20e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(30e18, 10e18, 30e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(40e18, 10e18, 10e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(50e18, 10e18, 40e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(60e18, 10e18, 60e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
  }

  function testAnkrBNBBorrowRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 borrowRate = ankrBnbInterestRateModel.getBorrowRate(3e18, 8e18, 1e18);
    uint256 util = ankrBnbInterestRateModel.utilizationRate(3e18, 8e18, 1e18);
    assertEq(util, 0.8e18); // utilization 80
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(800e18, 8e18, 8e18);
    util = ankrBnbInterestRateModel.utilizationRate(800e18, 8e18, 8e18);
    assertEq(util, 0.1e17); // utilization 1
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(80e18, 8e18, 8e18);
    util = ankrBnbInterestRateModel.utilizationRate(80e18, 8e18, 8e18);
    assertEq(util, 0.1e18); // utilization 10
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(40e18, 8e18, 8e18);
    util = ankrBnbInterestRateModel.utilizationRate(40e18, 8e18, 8e18);
    assertEq(util, 0.2e18); // utilization 20
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
  }

  function testAnkrBNBSupplyRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 supplyRate = ankrBnbInterestRateModel.getSupplyRate(3e18, 8e18, 1e18, 0.17e18);
    uint256 util = ankrBnbInterestRateModel.utilizationRate(3e18, 8e18, 1e18);
    assertEq(util, 0.8e18); // utilization 80
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    supplyRate = ankrBnbInterestRateModel.getSupplyRate(800e18, 8e18, 8e18, 0.17e18);
    util = ankrBnbInterestRateModel.utilizationRate(800e18, 8e18, 8e18);
    assertEq(util, 0.1e17); // utilization 1
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    supplyRate = ankrBnbInterestRateModel.getSupplyRate(80e18, 8e18, 8e18, 0.17e18);
    util = ankrBnbInterestRateModel.utilizationRate(80e18, 8e18, 8e18);
    assertEq(util, 0.1e18); // utilization 10
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    supplyRate = ankrBnbInterestRateModel.getSupplyRate(40e18, 8e18, 8e18, 0.17e18);
    util = ankrBnbInterestRateModel.utilizationRate(40e18, 8e18, 8e18);
    assertEq(util, 0.2e18); // utilization 20
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
  }

  function testWhitepaperBorrowRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 borrowRate = whitepaperInterestRateModel.getBorrowRate(0, 0, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(1e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(2e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(3e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(4e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(5e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(6e18, 10e18, 5e18);
    assertGe(_convertToPerYear(borrowRate), 0);
    assertLe(_convertToPerYear(borrowRate), 100e18);
  }

  function testWhitepaperSupplyRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 supplyRate = whitepaperInterestRateModel.getSupplyRate(0, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(1e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(2e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(3e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(4e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(5e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(6e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYear(supplyRate), 0);
    assertLe(_convertToPerYear(supplyRate), 100e18);
  }
}
