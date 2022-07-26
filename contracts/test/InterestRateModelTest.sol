// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";

import { AnkrBNBInterestRateModel } from "../compound/AnkrBNBInterestRateModel.sol";
import { JumpRateModel } from "../compound/JumpRateModel.sol";
import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";

contract InterestRateModelTest is BaseTest {
  AnkrBNBInterestRateModel ankrBnbInterestRateModel;
  JumpRateModel jumpRateModel;
  WhitePaperInterestRateModel whitepaperInterestRateModel;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    ankrBnbInterestRateModel = new AnkrBNBInterestRateModel(
      10512000,
      25.6e15,
      3e18,
      0.8e18,
      3,
      0xBb1Aa6e59E5163D8722a122cd66EBA614b59df0d
    );
    jumpRateModel = new JumpRateModel(
      10512000,
      0.2e17,
      0.2e18,
      2e18,
      0.9e18
    );
    whitepaperInterestRateModel = new WhitePaperInterestRateModel(
      10512000,
      0.2e17,
      0.2e18
    );
  }

  function testJumpRateBorrowRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 borrowRate = jumpRateModel.getBorrowRate(0, 0, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = jumpRateModel.getBorrowRate(1e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = jumpRateModel.getBorrowRate(2e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = jumpRateModel.getBorrowRate(3e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = jumpRateModel.getBorrowRate(4e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = jumpRateModel.getBorrowRate(5e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = jumpRateModel.getBorrowRate(6e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
  }

  function testJumpRateSupplyRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 supplyRate = jumpRateModel.getSupplyRate(0, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    jumpRateModel.getSupplyRate(10e18, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    jumpRateModel.getSupplyRate(20e18, 10e18, 20e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    jumpRateModel.getSupplyRate(30e18, 10e18, 30e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    jumpRateModel.getSupplyRate(40e18, 10e18, 10e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    jumpRateModel.getSupplyRate(50e18, 10e18, 40e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    jumpRateModel.getSupplyRate(60e18, 10e18, 60e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
  }

  function testAnkrBNBBorrowRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 borrowRate = ankrBnbInterestRateModel.getBorrowRate(0, 0, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(1e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(2e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(3e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(4e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(5e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = ankrBnbInterestRateModel.getBorrowRate(6e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
  }

  function testAnkrBNBSupplyRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 supplyRate = ankrBnbInterestRateModel.getSupplyRate(0, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    ankrBnbInterestRateModel.getSupplyRate(10e18, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    ankrBnbInterestRateModel.getSupplyRate(20e18, 10e18, 20e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    ankrBnbInterestRateModel.getSupplyRate(30e18, 10e18, 30e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    ankrBnbInterestRateModel.getSupplyRate(40e18, 10e18, 10e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    ankrBnbInterestRateModel.getSupplyRate(50e18, 10e18, 40e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    ankrBnbInterestRateModel.getSupplyRate(60e18, 10e18, 60e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
  }

  function testWhitepaperBorrowRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 borrowRate = whitepaperInterestRateModel.getBorrowRate(0, 0, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(1e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(2e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(3e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(4e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(5e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(6e18, 10e18, 5e18);
    assertGt(borrowRate, 0);
    assertLt(borrowRate, 100e18);
  }

  function testWhitepaperSupplyRate() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 supplyRate = whitepaperInterestRateModel.getSupplyRate(0, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    whitepaperInterestRateModel.getSupplyRate(1e18, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    whitepaperInterestRateModel.getSupplyRate(2e18, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    whitepaperInterestRateModel.getSupplyRate(3e18, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    whitepaperInterestRateModel.getSupplyRate(4e18, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    whitepaperInterestRateModel.getSupplyRate(5e18, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
    whitepaperInterestRateModel.getSupplyRate(6e18, 10e18, 5e18, 0.2e18);
    assertGt(supplyRate, 0);
    assertLt(supplyRate, 100e18);
  }
}
