// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { JarvisERC4626Test } from "./JarvisERC4626Test.sol";
import { JarvisTestConfig, JarvisTestConfigStorage } from "./JarvisTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

contract JarvisAssetTest is AbstractAssetTest {
  address masterPriceOracle = 0xb9e1c2B011f252B9931BBA7fcee418b95b6Bdc31; // master price oracle

  constructor() {
    test = AbstractERC4626Test(address(new JarvisERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new JarvisTestConfigStorage()));
    shouldRunTest = forChains(POLYGON_MAINNET);
  }

  function setUp() public override shouldRun(shouldRunTest) {}

  function setUpTestContract(bytes calldata testConfig) public override shouldRun(shouldRunTest) {
    (address asset, address pool) = abi.decode(testConfig, (address, address));

    test.setUpWithPool(MasterPriceOracle(masterPriceOracle), MockERC20(asset));

    test.setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override shouldRun(shouldRunTest) {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      bytes memory testConfig = testConfigStorage.getTestConfig(i);

      this.setUpTestContract(testConfig);

      (address asset, ) = abi.decode(testConfig, (address, address));

      test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
    }
  }

  function testAccumulatingRewardsOnDeposit() public shouldRun(shouldRunTest) {
    this.runTest(JarvisERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  }

  function testAccumulatingRewardsOnWithdrawal() public shouldRun(shouldRunTest) {
    this.runTest(JarvisERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  }

  function testClaimRewards() public shouldRun(shouldRunTest) {
    this.runTest(JarvisERC4626Test(address(test)).testClaimRewards);
  }
}