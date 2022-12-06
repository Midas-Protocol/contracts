// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ArrakisTestConfig, ArrakisTestConfigStorage } from "./ArrakisTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import "./ArrakisERC4626Test.sol";

contract ArrakisAssetTest is AbstractAssetTest {
  MasterPriceOracle masterPriceOracle;

  function afterForkSetUp() internal override {
    masterPriceOracle = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    test = AbstractERC4626Test(address(new ArrakisERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new ArrakisTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address asset, address pool) = abi.decode(testConfig, (address, address));

    test.setUpWithPool(masterPriceOracle, ERC20Upgradeable(asset));

    test.setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override fork(POLYGON_MAINNET) {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      bytes memory testConfig = testConfigStorage.getTestConfig(i);

      this.setUpTestContract(testConfig);

      (address asset, ) = abi.decode(testConfig, (address, address));

      test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
    }
  }

  function testDepositWithIncreasedVaultValue() public override fork(POLYGON_MAINNET) {
    this.runTest(test.testDepositWithIncreasedVaultValue);
  }

  function testDepositWithDecreasedVaultValue() public override fork(POLYGON_MAINNET) {
    this.runTest(test.testDepositWithDecreasedVaultValue);
  }

  function testWithdrawWithIncreasedVaultValue() public override fork(POLYGON_MAINNET) {
    this.runTest(test.testWithdrawWithIncreasedVaultValue);
  }

  function testWithdrawWithDecreasedVaultValue() public override fork(POLYGON_MAINNET) {
    this.runTest(test.testWithdrawWithDecreasedVaultValue);
  }

  function testAccumulatingRewardsOnDeposit() public fork(POLYGON_MAINNET) {
    this.runTest(ArrakisERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  }

  function testAccumulatingRewardsOnWithdrawal() public fork(POLYGON_MAINNET) {
    this.runTest(ArrakisERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  }

  function testClaimRewards() public fork(POLYGON_MAINNET) {
    this.runTest(ArrakisERC4626Test(address(test)).testClaimRewards);
  }
}
