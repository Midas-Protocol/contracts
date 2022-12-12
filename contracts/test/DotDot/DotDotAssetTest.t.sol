// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { DotDotTestConfigStorage } from "./DotDotTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import "./DotDotLpERC4626Test.sol";

// TODO adapt the test to run for the latest block
contract DotDotAssetTest is AbstractAssetTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    test = AbstractERC4626Test(address(new DotDotERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new DotDotTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address masterPriceOracle, address asset) = abi.decode(testConfig, (address, address));

    test.setUpWithPool(MasterPriceOracle(masterPriceOracle), ERC20Upgradeable(asset));

    test.setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override {
    if (shouldRunForChain(block.chainid)) {
      for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
        bytes memory testConfig = testConfigStorage.getTestConfig(i);

        this.setUpTestContract(testConfig);

        (, address asset) = abi.decode(testConfig, (address, address));

        test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
      }
    }
  }

  function testDepositWithIncreasedVaultValue() public override {
    this.runTest(test.testDepositWithIncreasedVaultValue);
  }

  function testDepositWithDecreasedVaultValue() public override {
    this.runTest(test.testDepositWithDecreasedVaultValue);
  }

  function testWithdrawWithIncreasedVaultValue() public override {
    this.runTest(test.testWithdrawWithIncreasedVaultValue);
  }

  function testWithdrawWithDecreasedVaultValue() public override {
    this.runTest(test.testWithdrawWithDecreasedVaultValue);
  }

  function testAccumulatingRewardsOnDeposit() public {
    this.runTest(DotDotERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    this.runTest(DotDotERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  }

  function testClaimRewards() public {
    this.runTest(DotDotERC4626Test(address(test)).testClaimRewards);
  }
}
