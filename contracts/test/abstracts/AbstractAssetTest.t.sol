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

  constructor() {}

  function setUp() public virtual {}

  function setUpTestContract(bytes calldata testConfig) public virtual {
    // test.setUp(MockERC20(address(IBeefyVault(testConfig.beefyVault).want())).symbol(), testConfig);
  }

  function runTest(function() external test) public {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      this.setUpTestContract(testConfigStorage.getTestConfig(i));
      test();
    }
  }

  function testInitializedValues() public virtual {
    // for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
    //   this.setUpTestContract(testConfigs[i]);
    //   test.testInitializedValues(asset.name(), asset.symbol());
    // }
  }

  function testPreviewDepositAndMintReturnTheSameValue() public {
    this.runTest(test.testPreviewDepositAndMintReturnTheSameValue);
  }

  function testPreviewWithdrawAndRedeemReturnTheSameValue() public {
    this.runTest(test.testPreviewWithdrawAndRedeemReturnTheSameValue);
  }

  function testDeposit() public {
    this.runTest(test.testDeposit);
  }

  function testDepositWithIncreasedVaultValue() public {
    this.runTest(test.testDepositWithIncreasedVaultValue);
  }

  function testDepositWithDecreasedVaultValue() public {
    this.runTest(test.testDepositWithDecreasedVaultValue);
  }

  function testMultipleDeposit() public {
    this.runTest(test.testMultipleDeposit);
  }

  function testMint() public {
    this.runTest(test.testMint);
  }

  function testMultipleMint() public {
    this.runTest(test.testMultipleMint);
  }

  function testWithdraw() public {
    this.runTest(test.testWithdraw);
  }

  function testWithdrawWithIncreasedVaultValue() public {
    this.runTest(test.testWithdrawWithIncreasedVaultValue);
  }

  function testWithdrawWithDecreasedVaultValue() public {
    this.runTest(test.testWithdrawWithDecreasedVaultValue);
  }

  function testMultipleWithdraw() public {
    this.runTest(test.testMultipleWithdraw);
  }

  function testRedeem() public {
    this.runTest(test.testRedeem);
  }

  function testMultipleRedeem() public {
    this.runTest(test.testMultipleRedeem);
  }

  function testPauseContract() public {
    this.runTest(test.testPauseContract);
  }

  function testEmergencyWithdrawAndPause() public {
    this.runTest(test.testEmergencyWithdrawAndPause);
  }

  function testEmergencyWithdrawAndRedeem() public {
    this.runTest(test.testEmergencyWithdrawAndRedeem);
  }
}
