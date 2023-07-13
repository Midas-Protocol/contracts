// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";

import "../../midas/irms/AdjustableAnkrBNBIrm.sol";

contract AdjustableAnkrIrmTest is BaseTest {
  AdjustableAnkrBNBIrm adjustableAnkrBNBIrm;
  AnkrRateProviderParams ankrBnbParams;
  AdjustableAnkrInterestRateModelParams irmParams;

  address ANKR_BNB_RATE_PROVIDER = 0xCb0006B31e6b403fEeEC257A8ABeE0817bEd7eBa;
  address ANKR_BNB_BOND = 0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827;

  function afterForkSetUp() internal override {
    irmParams = AdjustableAnkrInterestRateModelParams({
      blocksPerYear: 10512000,
      multiplierPerYear: 0.4e18,
      jumpMultiplierPerYear: 4e18,
      kink: 0.75e18
    });
    if (block.chainid == BSC_MAINNET) {
      ankrBnbParams = AnkrRateProviderParams({ day: 7, rate_provider: ANKR_BNB_RATE_PROVIDER, abond: ANKR_BNB_BOND });
      adjustableAnkrBNBIrm = new AdjustableAnkrBNBIrm(irmParams, ankrBnbParams);
    }
  }

  function testAnkrBscIrm() public fork(BSC_MAINNET) {
    testAnkrBNBBorrowModelRate();
    testUpdateIrmParams();
  }

  function _convertToPerYearBsc(uint256 value) internal pure returns (uint256) {
    return value * 10512000;
  }

  function testAnkrBNBBorrowModelRate() internal {
    vm.mockCall(
      address(ANKR_BNB_RATE_PROVIDER),
      abi.encodeWithSelector(IAnkrRateProvider.averagePercentageRate.selector),
      abi.encode(2.5e18)
    );
    // utilization 0 -> borrow rate: 2.5% // supply rate: 0%
    uint256 supplyRate = adjustableAnkrBNBIrm.getSupplyRate(800e18, 0, 8e18, 0.1e18);
    uint256 borrowRate = adjustableAnkrBNBIrm.getBorrowRate(800e18, 0, 8e18);
    uint256 util = adjustableAnkrBNBIrm.utilizationRate(800e18, 0, 8e18);
    assertEq(util, 0);
    assertApproxEqRel(_convertToPerYearBsc(borrowRate) * 100, 2.5e18, 1e16, "!borrow rate for utilization 0");
    assertApproxEqRel(_convertToPerYearBsc(supplyRate) * 100, 0, 1e16, "!supply rate for utilization 0");

    // utilization 1 -> borrow rate: 2.89% // supply rate: 0.026%
    supplyRate = adjustableAnkrBNBIrm.getSupplyRate(800e18, 8e18, 8e18, 0.1e18);
    borrowRate = adjustableAnkrBNBIrm.getBorrowRate(800e18, 8e18, 8e18);
    util = adjustableAnkrBNBIrm.utilizationRate(800e18, 8e18, 8e18);
    assertEq(util, 0.1e17);
    assertApproxEqRel(_convertToPerYearBsc(borrowRate) * 100, 2.9e18, 1e16, "!borrow rate for utilization 1");
    assertApproxEqRel(_convertToPerYearBsc(supplyRate) * 100, 0.026e18, 1e16, "!borrow rate for utilization 1");

    // utilization 10 -> borrow rate: 6.5% // supply rate: 0.585%
    supplyRate = adjustableAnkrBNBIrm.getSupplyRate(80e18, 8e18, 8e18, 0.1e18);
    borrowRate = adjustableAnkrBNBIrm.getBorrowRate(80e18, 8e18, 8e18);
    util = adjustableAnkrBNBIrm.utilizationRate(80e18, 8e18, 8e18);
    assertEq(util, 0.1e18);
    assertApproxEqRel(_convertToPerYearBsc(borrowRate) * 100, 6.5e18, 1e16, "!borrow rate for utilization 10");
    assertApproxEqRel(_convertToPerYearBsc(supplyRate) * 100, 0.585e18, 1e16, "!supply rate for utilization 10");

    // utilization 20 -> borrow rate: 10.5% // supply rate: 1.89%
    supplyRate = adjustableAnkrBNBIrm.getSupplyRate(40e18, 8e18, 8e18, 0.1e18);
    borrowRate = adjustableAnkrBNBIrm.getBorrowRate(40e18, 8e18, 8e18);
    util = adjustableAnkrBNBIrm.utilizationRate(40e18, 8e18, 8e18);
    assertEq(util, 0.2e18);
    assertApproxEqRel(_convertToPerYearBsc(borrowRate) * 100, 10.5e18, 1e16, "!borrow rate for utilization 20");
    assertApproxEqRel(_convertToPerYearBsc(supplyRate) * 100, 1.89e18, 1e16, "!supply rate for utilization 20");

    // utilization 75 -> borrow rate: 32.5% // supply rate: 21.9%
    supplyRate = adjustableAnkrBNBIrm.getSupplyRate(3.5e18, 7.5e18, 1e18, 0.1e18);
    borrowRate = adjustableAnkrBNBIrm.getBorrowRate(3.5e18, 7.5e18, 1e18);
    util = adjustableAnkrBNBIrm.utilizationRate(3.5e18, 7.5e18, 1e18);
    assertEq(util, 0.75e18);
    assertApproxEqRel(_convertToPerYearBsc(borrowRate) * 100, 32.5e18, 1e16, "!borrow rate for utilization 75");
    assertApproxEqRel(_convertToPerYearBsc(supplyRate) * 100, 21.9e18, 1e16, "!supply rate for utilization 75");

    // utilization 90 -> borrow rate: 92.5% // supply rate: 74.9%
    supplyRate = adjustableAnkrBNBIrm.getSupplyRate(8e18, 7.2e18, 7.2e18, 0.1e18);
    borrowRate = adjustableAnkrBNBIrm.getBorrowRate(8e18, 7.2e18, 7.2e18);
    util = adjustableAnkrBNBIrm.utilizationRate(8e18, 7.2e18, 7.2e18);
    assertEq(util, 0.9e18);
    assertApproxEqRel(_convertToPerYearBsc(borrowRate) * 100, 92.5e18, 1e16, "!borrow rate for utilization 90");
    assertApproxEqRel(_convertToPerYearBsc(supplyRate) * 100, 74.9e18, 1e16, "!supply rate for utilization 90");
  }

  function testUpdateIrmParams() internal {
    AdjustableAnkrInterestRateModelParams memory newParams = AdjustableAnkrInterestRateModelParams({
      blocksPerYear: 10000,
      multiplierPerYear: 0.4e18,
      jumpMultiplierPerYear: 4e18,
      kink: 0.75e18
    });

    adjustableAnkrBNBIrm._setIrmParameters(newParams);
    vm.roll(1);

    assertEq(adjustableAnkrBNBIrm.blocksPerYear(), newParams.blocksPerYear);
    assertEq(adjustableAnkrBNBIrm.multiplierPerBlock(), newParams.multiplierPerYear / newParams.blocksPerYear);
  }
}
