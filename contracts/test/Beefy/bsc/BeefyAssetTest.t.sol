// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { BeefyERC4626Test } from "../BeefyERC4626Test.sol";
import { BeefyBscTestConfigStorage } from "./BeefyTestConfig.sol";
import { MidasERC4626, BeefyERC4626, IBeefyVault } from "../../../midas/strategies/BeefyERC4626.sol";
import { AbstractAssetTest } from "../../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../../abstracts/ITestConfigStorage.sol";

// TODO adapt test to run for the latest block
contract BeefyBscAssetTest is AbstractAssetTest {
  address lpChef = 0x1083926054069AaD75d7238E9B809b0eF9d94e5B; // bshare

  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    test = AbstractERC4626Test(address(new BeefyERC4626Test()));
    test.setDepositAmount(1e16);
    testConfigStorage = ITestConfigStorage(address(new BeefyBscTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address beefyVault, uint256 withdrawalFee) = abi.decode(testConfig, (address, uint256));

    test._setUp(
      MockERC20(address(IBeefyVault(beefyVault).want())).symbol(),
      abi.encode(beefyVault, withdrawalFee, lpChef)
    );
  }

  function testInitializedValues() public override {
    if (shouldRunForChain(block.chainid)) {
      for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
        bytes memory testConfig = testConfigStorage.getTestConfig(i);

        this.setUpTestContract(testConfig);

        (address beefyVault, ) = abi.decode(testConfig, (address, uint256));

        MockERC20 asset = MockERC20(address(IBeefyVault(beefyVault).want()));

        test.testInitializedValues(asset.name(), asset.symbol());
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
}
