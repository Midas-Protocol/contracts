// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../config/BaseTest.t.sol";

import { AdjustableJumpRateModel, InterestRateModelParams } from "../../midas/irms/AdjustableJumpRateModel.sol";

contract InterestRateModelTest is BaseTest {
  AdjustableJumpRateModel adjustableJumpRateModel;
  InterestRateModelParams params;
  InterestRateModelParams newParams;

  function setUp() public override {
    params = InterestRateModelParams({
      blocksPerYear: 10512000,
      baseRatePerYear: 0.5e16,
      multiplierPerYear: 0.18e18,
      jumpMultiplierPerYear: 4e18,
      kink: 0.8e18
    });
    adjustableJumpRateModel = new AdjustableJumpRateModel(params);
  }

  function testUpdateJrmParams() public {
    assertEq(adjustableJumpRateModel.blocksPerYear(), params.blocksPerYear);
    assertEq(adjustableJumpRateModel.baseRatePerBlock(), params.baseRatePerYear / params.blocksPerYear);

    newParams = InterestRateModelParams({
      blocksPerYear: 512000,
      baseRatePerYear: 0.7e16,
      multiplierPerYear: 0.18e18,
      jumpMultiplierPerYear: 4e18,
      kink: 0.8e18
    });

    adjustableJumpRateModel._setIrmParameters(newParams);
    vm.roll(1);

    assertEq(adjustableJumpRateModel.blocksPerYear(), newParams.blocksPerYear);
    assertEq(adjustableJumpRateModel.baseRatePerBlock(), newParams.baseRatePerYear / newParams.blocksPerYear);
  }
}
