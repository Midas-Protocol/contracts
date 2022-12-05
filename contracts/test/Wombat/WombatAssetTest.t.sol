// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { WombatERC4626Test } from "./WombatLpERC4626Test.sol";
import { WombatTestConfig, WombatTestConfigStorage } from "./WombatTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

// Tested on block 23534949
contract WombatAssetTest is AbstractAssetTest {
  function afterForkSetUp() override intenral {
    test = AbstractERC4626Test(address(new WombatERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new WombatTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address asset, uint256 poolId, ERC20Upgradeable[] memory rewardTokens) = abi.decode(
      testConfig,
      (address, uint256, ERC20Upgradeable[])
    );

    test.setUpWithPool(MasterPriceOracle(ap.getAddress("MasterPriceOracle")), ERC20Upgradeable(asset));

    test.setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override forkAtBlock(BSC_MAINNET, 23534949) {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      bytes memory testConfig = testConfigStorage.getTestConfig(i);

      this.setUpTestContract(testConfig);

      (address asset, , ) = abi.decode(testConfig, (address, uint256, ERC20Upgradeable[]));

      test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
    }
  }

  function testClaimRewards() public forkAtBlock(BSC_MAINNET, 23534949) {
    this.runTest(WombatERC4626Test(address(test)).testClaimRewards);
  }
}
