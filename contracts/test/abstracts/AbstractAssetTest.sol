// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { AbstractERC4626Test } from "./AbstractERC4626Test.sol";
import { ITestConfigStorage } from "./ITestConfigStorage.sol";

contract AbstractAssetTest is BaseTest {
  AbstractERC4626Test public test;
  ITestConfigStorage public testConfigStorage;
  bool public shouldRunTest;

  constructor() {}

  function setUp() public virtual shouldRun(shouldRunTest) {}

  function setUpTestContract(bytes calldata testConfig) public virtual shouldRun(shouldRunTest) {
    // test.setUp(MockERC20(address(IBeefyVault(testConfig.beefyVault).want())).symbol(), testConfig);
  }

  function runTest(function() external test) public shouldRun(shouldRunTest) {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      this.setUpTestContract(testConfigStorage.getTestConfig(i));
      test();
    }
  }

  function testInitializedValues() public virtual shouldRun(shouldRunTest) {
    // for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
    //   this.setUpTestContract(testConfigs[i]);
    //   test.testInitializedValues(asset.name(), asset.symbol());
    // }
  }

  function testPreviewDepositAndMintReturnTheSameValue() public shouldRun(shouldRunTest) {
    this.runTest(test.testPreviewDepositAndMintReturnTheSameValue);
  }

  function testPreviewWithdrawAndRedeemReturnTheSameValue() public shouldRun(shouldRunTest) {
    this.runTest(test.testPreviewWithdrawAndRedeemReturnTheSameValue);
  }

  function testDeposit() public shouldRun(shouldRunTest) {
    this.runTest(test.testDeposit);
  }

  function testDepositWithIncreasedVaultValue() public shouldRun(shouldRunTest) {
    this.runTest(test.testDepositWithIncreasedVaultValue);
  }

  function testDepositWithDecreasedVaultValue() public shouldRun(shouldRunTest) {
    this.runTest(test.testDepositWithDecreasedVaultValue);
  }

  function testMultipleDeposit() public shouldRun(shouldRunTest) {
    this.runTest(test.testMultipleDeposit);
  }

  function testMint() public shouldRun(shouldRunTest) {
    this.runTest(test.testMint);
  }

  function testMultipleMint() public shouldRun(shouldRunTest) {
    this.runTest(test.testMultipleMint);
  }

  function testWithdraw() public shouldRun(shouldRunTest) {
    this.runTest(test.testWithdraw);
  }

  function testWithdrawWithIncreasedVaultValue() public shouldRun(shouldRunTest) {
    this.runTest(test.testWithdrawWithIncreasedVaultValue);
  }

  function testWithdrawWithDecreasedVaultValue() public shouldRun(shouldRunTest) {
    this.runTest(test.testWithdrawWithDecreasedVaultValue);
  }

  function testMultipleWithdraw() public shouldRun(shouldRunTest) {
    this.runTest(test.testMultipleWithdraw);
  }

  function testRedeem() public shouldRun(shouldRunTest) {
    this.runTest(test.testRedeem);
  }

  function testMultipleRedeem() public shouldRun(shouldRunTest) {
    this.runTest(test.testMultipleRedeem);
  }

  function testPauseContract() public shouldRun(shouldRunTest) {
    this.runTest(test.testPauseContract);
  }

  function testEmergencyWithdrawAndPause() public shouldRun(shouldRunTest) {
    this.runTest(test.testEmergencyWithdrawAndPause);
  }

  function testEmergencyWithdrawAndRedeem() public shouldRun(shouldRunTest) {
    this.runTest(test.testEmergencyWithdrawAndRedeem);
  }
}
