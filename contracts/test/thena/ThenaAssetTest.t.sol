// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ThenaERC4626Test } from "./ThenaERC4626Test.sol";
import { ThenaTestConfigStorage } from "./ThenaTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract ThenaAssetTest is AbstractAssetTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    test = AbstractERC4626Test(address(new ThenaERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new ThenaTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address asset) = abi.decode(testConfig, (address));

    test.setUpWithPool(MasterPriceOracle(ap.getAddress("MasterPriceOracle")), ERC20Upgradeable(asset));

    test._setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override {
    if (shouldRunForChain(block.chainid)) {
      for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
        bytes memory testConfig = testConfigStorage.getTestConfig(i);

        this.setUpTestContract(testConfig);

        (address asset, ) = abi.decode(testConfig, (address, address));

        test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
      }
    }
  }
}