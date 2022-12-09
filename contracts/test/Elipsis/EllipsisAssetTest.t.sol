// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { EllipsisTestConfigStorage } from "./EllipsisTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import "./EllipsisERC4626Test.sol";

contract EllipsisAssetTest is AbstractAssetTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    test = AbstractERC4626Test(address(new EllipsisERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new EllipsisTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    address asset = abi.decode(testConfig, (address));

    test.setUpWithPool(MasterPriceOracle(ap.getAddress("MasterPriceOracle")), ERC20Upgradeable(asset));

    test._setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override {
    if (shouldRunForChain(block.chainid)) {
      for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
        bytes memory testConfig = testConfigStorage.getTestConfig(i);

        this.setUpTestContract(testConfig);

        address asset = abi.decode(testConfig, (address));

        test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
      }
    }
  }
}
