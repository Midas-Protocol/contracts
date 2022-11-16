// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { EllipsisERC4626Test } from "./EllipsisERC4626Test.sol";
import { EllipsisTestConfig, EllipsisTestConfigStorage } from "./EllipsisTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

contract EllipsisAssetTest is AbstractAssetTest {
  address masterPriceOracle = 0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA; // master price oracle

  constructor() forkAtBlock(BSC_MAINNET, 20238373) {
    test = AbstractERC4626Test(address(new EllipsisERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new EllipsisTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    address asset = abi.decode(testConfig, (address));

    test.setUpWithPool(MasterPriceOracle(masterPriceOracle), ERC20Upgradeable(asset));

    test.setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      bytes memory testConfig = testConfigStorage.getTestConfig(i);

      this.setUpTestContract(testConfig);

      address asset = abi.decode(testConfig, (address));

      test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
    }
  }
}
