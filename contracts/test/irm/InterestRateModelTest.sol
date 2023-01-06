// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";

import { AnkrBNBInterestRateModel, IAnkrBNBR } from "../../midas/irms/AnkrBNBInterestRateModel.sol";
import { AnkrFTMInterestRateModel, IAnkrFTMR } from "../../midas/irms/AnkrFTMInterestRateModel.sol";
import { JumpRateModel } from "../../compound/JumpRateModel.sol";
import { WhitePaperInterestRateModel } from "../../compound/WhitePaperInterestRateModel.sol";

contract InterestRateModelTest is BaseTest {
  AnkrBNBInterestRateModel ankrBnbInterestRateModel2;
  AnkrFTMInterestRateModel ankrFtmInterestRateModel;
  JumpRateModel jumpRateModel;
  JumpRateModel mimoRateModel;
  WhitePaperInterestRateModel whitepaperInterestRateModel;
  address ANKR_BNB_R = 0xBb1Aa6e59E5163D8722a122cd66EBA614b59df0d;
  address ANKR_FTM_R = 0xB42bF10ab9Df82f9a47B86dd76EEE4bA848d0Fa2;
  uint8 day = 3;

  function afterForkSetUp() internal override {
    if (block.chainid == BSC_MAINNET) {
      ankrBnbInterestRateModel2 = new AnkrBNBInterestRateModel(10512000, 0.5e16, 3e18, 0.85e18, day, ANKR_BNB_R);
      jumpRateModel = new JumpRateModel(10512000, 0.2e17, 0.18e18, 4e18, 0.8e18);
      whitepaperInterestRateModel = new WhitePaperInterestRateModel(10512000, 0.2e17, 0.2e18);
    } else if (block.chainid == POLYGON_MAINNET) {
      mimoRateModel = new JumpRateModel(13665600, 2e18, 0.4e17, 4e18, 0.8e18);
      jumpRateModel = new JumpRateModel(13665600, 0.2e17, 0.18e18, 2e18, 0.8e18);
    } else if (block.chainid == FANTOM_OPERA) {
      ankrFtmInterestRateModel = new AnkrFTMInterestRateModel(21024000, 0.5e16, 3e18, 0.85e18, day, ANKR_FTM_R);
      jumpRateModel = new JumpRateModel(21024000, 0.2e17, 0.18e18, 4e18, 0.8e18);
      whitepaperInterestRateModel = new WhitePaperInterestRateModel(21024000, 0.2e17, 0.2e18);
    }
  }

  function testFantom() public fork(FANTOM_OPERA) {
    testJumpRateBorrowRate();
    testJumpRateSupplyRate();
    testAnkrFTMBorrowModelRate();
    testAnkrFTMSupplyModelRate();
    testWhitepaperBorrowRate();
    testWhitepaperSupplyRate();
  }

  function testBsc() public fork(BSC_MAINNET) {
    testJumpRateBorrowRate();
    testJumpRateSupplyRate();
    testAnkrBNBBorrowModel2Rate();
    testAnkrBNBSupplyModel2Rate();
    testWhitepaperBorrowRate();
    testWhitepaperSupplyRate();
  }

  function testPolygon() public fork(POLYGON_MAINNET) {
    testJumpRateBorrowRatePolygon();
  }

  function _convertToPerYearBsc(uint256 value) internal pure returns (uint256) {
    return value * 10512000;
  }

  function _convertToPerYearPolygon(uint256 value) internal pure returns (uint256) {
    return value * 13665600;
  }

  function _convertToPerYearFtm(uint256 value) internal pure returns (uint256) {
    return value * 21024000;
  }

  function testJumpRateBorrowRatePolygon() internal {
    uint256 borrowRate = mimoRateModel.getBorrowRate(0, 0, 5e18);
    assertGe(_convertToPerYearPolygon(borrowRate), 0);
    assertLe(_convertToPerYearPolygon(borrowRate), 100e18);
    borrowRate = mimoRateModel.getBorrowRate(1e18, 10e18, 5e18);
    assertGe(_convertToPerYearPolygon(borrowRate), 0);
    assertLe(_convertToPerYearPolygon(borrowRate), 100e18);
    borrowRate = mimoRateModel.getBorrowRate(2e18, 10e18, 5e18);
    assertGe(_convertToPerYearPolygon(borrowRate), 0);
    assertLe(_convertToPerYearPolygon(borrowRate), 100e18);
    borrowRate = mimoRateModel.getBorrowRate(3e18, 10e18, 5e18);
    assertGe(_convertToPerYearPolygon(borrowRate), 0);
    assertLe(_convertToPerYearPolygon(borrowRate), 100e18);
    borrowRate = mimoRateModel.getBorrowRate(4e18, 10e18, 5e18);
    assertGe(_convertToPerYearPolygon(borrowRate), 0);
    assertLe(_convertToPerYearPolygon(borrowRate), 100e18);
    borrowRate = mimoRateModel.getBorrowRate(5e18, 10e18, 5e18);
    assertGe(_convertToPerYearPolygon(borrowRate), 0);
    assertLe(_convertToPerYearPolygon(borrowRate), 100e18);
    borrowRate = mimoRateModel.getBorrowRate(6e18, 10e18, 5e18);
    assertGe(_convertToPerYearPolygon(borrowRate), 0);
    assertLe(_convertToPerYearPolygon(borrowRate), 100e18);
  }

  function testJumpRateBorrowRate() internal {
    uint256 borrowRate = jumpRateModel.getBorrowRate(0, 0, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(1e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(2e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(3e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(4e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(5e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = jumpRateModel.getBorrowRate(6e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
  }

  function testJumpRateSupplyRate() internal {
    uint256 supplyRate = jumpRateModel.getSupplyRate(0, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(10e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(20e18, 10e18, 20e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(30e18, 10e18, 30e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(40e18, 10e18, 10e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(50e18, 10e18, 40e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    jumpRateModel.getSupplyRate(60e18, 10e18, 60e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
  }

  function testAnkrFTMBorrowModelRate() internal {
    vm.mockCall(
      address(ANKR_FTM_R),
      abi.encodeWithSelector(IAnkrFTMR.getRatioHistory.selector, day),
      abi.encode(5.12e18)
    );
    uint256 borrowRate = ankrFtmInterestRateModel.getBorrowRate(800e18, 8e18, 8e18);
    uint256 util = ankrFtmInterestRateModel.utilizationRate(800e18, 8e18, 8e18);
    assertEq(util, 0.1e17); // utilization 1
    assertApproxEqAbs(
      _convertToPerYearFtm(borrowRate) * 100,
      0.858e17,
      uint256(1e14),
      "!borrow rate for utilization 1"
    );
    borrowRate = ankrFtmInterestRateModel.getBorrowRate(80e18, 8e18, 8e18);
    util = ankrFtmInterestRateModel.utilizationRate(80e18, 8e18, 8e18);
    assertEq(util, 0.1e18); // utilization 10
    assertApproxEqAbs(
      _convertToPerYearFtm(borrowRate) * 100,
      0.628e18,
      uint256(1e14),
      "!borrow rate for utilization 10"
    );
    borrowRate = ankrFtmInterestRateModel.getBorrowRate(40e18, 8e18, 8e18);
    util = ankrFtmInterestRateModel.utilizationRate(40e18, 8e18, 8e18);
    assertEq(util, 0.2e18); // utilization 20
    assertApproxEqAbs(
      _convertToPerYearFtm(borrowRate) * 100,
      1.2303e18,
      uint256(1e14),
      "!borrow rate for utilization 20"
    );
    borrowRate = ankrFtmInterestRateModel.getBorrowRate(3e18, 8e18, 1e18);
    util = ankrFtmInterestRateModel.utilizationRate(3e18, 8e18, 1e18);
    assertEq(util, 0.8e18); // utilization 80
    assertApproxEqAbs(
      _convertToPerYearFtm(borrowRate) * 100,
      4.8444e18,
      uint256(1e14),
      "!borrow rate for utilization 80"
    );
    borrowRate = ankrFtmInterestRateModel.getBorrowRate(8e18, 7.2e18, 7.2e18);
    util = ankrFtmInterestRateModel.utilizationRate(8e18, 7.2e18, 7.2e18);
    assertEq(util, 0.9e18); // utilization 90
    assertApproxEqAbs(
      _convertToPerYearFtm(borrowRate) * 100,
      20.4468e18,
      uint256(1e14),
      "!borrow rate for utilization 90"
    );
  }

  function testAnkrBNBBorrowModel2Rate() internal {
    vm.mockCall(
      address(ANKR_BNB_R),
      abi.encodeWithSelector(IAnkrBNBR.averagePercentageRate.selector, day),
      abi.encode(5.12e18)
    );
    uint256 borrowRate = ankrBnbInterestRateModel2.getBorrowRate(800e18, 8e18, 8e18);
    uint256 util = ankrBnbInterestRateModel2.utilizationRate(800e18, 8e18, 8e18);
    assertEq(util, 0.1e17); // utilization 1
    assertApproxEqAbs(
      _convertToPerYearBsc(borrowRate) * 100,
      0.858e17,
      uint256(1e14),
      "!borrow rate for utilization 1"
    );
    borrowRate = ankrBnbInterestRateModel2.getBorrowRate(80e18, 8e18, 8e18);
    util = ankrBnbInterestRateModel2.utilizationRate(80e18, 8e18, 8e18);
    assertEq(util, 0.1e18); // utilization 10
    assertApproxEqAbs(
      _convertToPerYearBsc(borrowRate) * 100,
      0.628e18,
      uint256(1e14),
      "!borrow rate for utilization 10"
    );
    borrowRate = ankrBnbInterestRateModel2.getBorrowRate(40e18, 8e18, 8e18);
    util = ankrBnbInterestRateModel2.utilizationRate(40e18, 8e18, 8e18);
    assertEq(util, 0.2e18); // utilization 20
    assertApproxEqAbs(
      _convertToPerYearBsc(borrowRate) * 100,
      1.2303e18,
      uint256(1e14),
      "!borrow rate for utilization 20"
    );
    borrowRate = ankrBnbInterestRateModel2.getBorrowRate(3e18, 8e18, 1e18);
    util = ankrBnbInterestRateModel2.utilizationRate(3e18, 8e18, 1e18);
    assertEq(util, 0.8e18); // utilization 80
    assertApproxEqAbs(
      _convertToPerYearBsc(borrowRate) * 100,
      4.8444e18,
      uint256(1e14),
      "!borrow rate for utilization 80"
    );
    borrowRate = ankrBnbInterestRateModel2.getBorrowRate(8e18, 7.2e18, 7.2e18);
    util = ankrBnbInterestRateModel2.utilizationRate(8e18, 7.2e18, 7.2e18);
    assertEq(util, 0.9e18); // utilization 90
    assertApproxEqAbs(
      _convertToPerYearBsc(borrowRate) * 100,
      20.4468e18,
      uint256(1e14),
      "!borrow rate for utilization 90"
    );
  }

  function testAnkrFTMSupplyModelRate() internal {
    vm.mockCall(
      address(ANKR_FTM_R),
      abi.encodeWithSelector(IAnkrFTMR.getRatioHistory.selector, day),
      abi.encode(5.12e18)
    );
    uint256 supplyRate = ankrFtmInterestRateModel.getSupplyRate(3e18, 8e18, 1e18, 0.1e18);
    uint256 util = ankrFtmInterestRateModel.utilizationRate(3e18, 8e18, 1e18);
    assertEq(util, 0.8e18); // utilization 80
    assertApproxEqAbs(
      _convertToPerYearFtm(supplyRate) * 100,
      3.488e18,
      uint256(1e14),
      "!supply rate for utilization 80"
    );
    supplyRate = ankrFtmInterestRateModel.getSupplyRate(800e18, 8e18, 8e18, 0.1e18);
    util = ankrFtmInterestRateModel.utilizationRate(800e18, 8e18, 8e18);
    assertEq(util, 0.1e17); // utilization 1
    assertApproxEqAbs(_convertToPerYearFtm(supplyRate) * 100, 0.8e15, uint256(1e14), "!supply rate for utilization 1");
    supplyRate = ankrFtmInterestRateModel.getSupplyRate(80e18, 8e18, 8e18, 0.1e18);
    util = ankrFtmInterestRateModel.utilizationRate(80e18, 8e18, 8e18);
    assertEq(util, 0.1e18); // utilization 10
    assertApproxEqAbs(
      _convertToPerYearFtm(supplyRate) * 100,
      0.565e17,
      uint256(1e14),
      "!supply rate for utilization 10"
    );
    supplyRate = ankrFtmInterestRateModel.getSupplyRate(40e18, 8e18, 8e18, 0.1e18);
    util = ankrFtmInterestRateModel.utilizationRate(40e18, 8e18, 8e18);
    assertEq(util, 0.2e18); // utilization 20
    assertApproxEqAbs(
      _convertToPerYearFtm(supplyRate) * 100,
      0.2215e18,
      uint256(1e14),
      "!supply rate for utilization 20"
    );
    supplyRate = ankrFtmInterestRateModel.getSupplyRate(8e18, 7.2e18, 7.2e18, 0.1e18);
    util = ankrFtmInterestRateModel.utilizationRate(8e18, 7.2e18, 7.2e18);
    assertEq(util, 0.9e18); // utilization 90
    assertApproxEqAbs(
      _convertToPerYearFtm(supplyRate) * 100,
      16.5619e18,
      uint256(1e14),
      "!supply rate for utilization 90"
    );
  }

  function testAnkrBNBSupplyModel2Rate() internal {
    vm.mockCall(
      address(ANKR_BNB_R),
      abi.encodeWithSelector(IAnkrBNBR.averagePercentageRate.selector, day),
      abi.encode(5.12e18)
    );
    uint256 supplyRate = ankrBnbInterestRateModel2.getSupplyRate(3e18, 8e18, 1e18, 0.1e18);
    uint256 util = ankrBnbInterestRateModel2.utilizationRate(3e18, 8e18, 1e18);
    assertEq(util, 0.8e18); // utilization 80
    assertApproxEqAbs(
      _convertToPerYearBsc(supplyRate) * 100,
      3.488e18,
      uint256(1e14),
      "!supply rate for utilization 80"
    );
    supplyRate = ankrBnbInterestRateModel2.getSupplyRate(800e18, 8e18, 8e18, 0.1e18);
    util = ankrBnbInterestRateModel2.utilizationRate(800e18, 8e18, 8e18);
    assertEq(util, 0.1e17); // utilization 1
    assertApproxEqAbs(_convertToPerYearBsc(supplyRate) * 100, 0.8e15, uint256(1e14), "!supply rate for utilization 1");
    supplyRate = ankrBnbInterestRateModel2.getSupplyRate(80e18, 8e18, 8e18, 0.1e18);
    util = ankrBnbInterestRateModel2.utilizationRate(80e18, 8e18, 8e18);
    assertEq(util, 0.1e18); // utilization 10
    assertApproxEqAbs(
      _convertToPerYearBsc(supplyRate) * 100,
      0.565e17,
      uint256(1e14),
      "!supply rate for utilization 10"
    );
    supplyRate = ankrBnbInterestRateModel2.getSupplyRate(40e18, 8e18, 8e18, 0.1e18);
    util = ankrBnbInterestRateModel2.utilizationRate(40e18, 8e18, 8e18);
    assertEq(util, 0.2e18); // utilization 20
    assertApproxEqAbs(
      _convertToPerYearBsc(supplyRate) * 100,
      0.2215e18,
      uint256(1e14),
      "!supply rate for utilization 20"
    );
    supplyRate = ankrBnbInterestRateModel2.getSupplyRate(8e18, 7.2e18, 7.2e18, 0.1e18);
    util = ankrBnbInterestRateModel2.utilizationRate(8e18, 7.2e18, 7.2e18);
    assertEq(util, 0.9e18); // utilization 90
    assertApproxEqAbs(
      _convertToPerYearBsc(supplyRate) * 100,
      16.5619e18,
      uint256(1e14),
      "!supply rate for utilization 90"
    );
  }

  function testWhitepaperBorrowRate() internal {
    uint256 borrowRate = whitepaperInterestRateModel.getBorrowRate(0, 0, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(1e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(2e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(3e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(4e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(5e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
    borrowRate = whitepaperInterestRateModel.getBorrowRate(6e18, 10e18, 5e18);
    assertGe(_convertToPerYearBsc(borrowRate), 0);
    assertLe(_convertToPerYearBsc(borrowRate), 100e18);
  }

  function testWhitepaperSupplyRate() internal {
    uint256 supplyRate = whitepaperInterestRateModel.getSupplyRate(0, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(1e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(2e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(3e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(4e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(5e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
    whitepaperInterestRateModel.getSupplyRate(6e18, 10e18, 5e18, 0.2e18);
    assertGe(_convertToPerYearBsc(supplyRate), 0);
    assertLe(_convertToPerYearBsc(supplyRate), 100e18);
  }
}
