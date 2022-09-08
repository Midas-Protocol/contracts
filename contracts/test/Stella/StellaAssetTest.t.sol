// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { StellaERC4626Test } from "./StellaLpERC4626Test.sol";
import { StellaTestConfig, StellaTestConfigStorage } from "./StellaTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

// Using 2BRL
// Tested on block 19052824
contract StellaAssetTest is AbstractAssetTest {
  address masterPriceOracle = 0x14C15B9ec83ED79f23BF71D51741f58b69ff1494; // master price oracle

  constructor() {
    test = AbstractERC4626Test(address(new StellaERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new StellaTestConfigStorage()));
    shouldRunTest = forChains(MOONBEAM_MAINNET);
  }

  function setUp() public override shouldRun(shouldRunTest) {}

  function setUpTestContract(bytes calldata testConfig) public override shouldRun(shouldRunTest) {
    (address asset, uint256 poolId, address[] memory rewardTokens) = abi.decode(testConfig, (address, uint256, address[]));

    test.setUpWithPool(MasterPriceOracle(masterPriceOracle), MockERC20(asset));

    test.setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override shouldRun(shouldRunTest) {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      bytes memory testConfig = testConfigStorage.getTestConfig(i);

      this.setUpTestContract(testConfig);

      (address asset, , ) = abi.decode(testConfig, (address, uint256, address[]));

      test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
    }
  }

  function testAccumulatingRewardsOnDeposit() public shouldRun(shouldRunTest) {
    this.runTest(StellaERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  }

  function testAccumulatingRewardsOnWithdrawal() public shouldRun(shouldRunTest) {
    this.runTest(StellaERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  }

  function testClaimRewards() public shouldRun(shouldRunTest) {
    this.runTest(StellaERC4626Test(address(test)).testClaimRewards);
  }
}
