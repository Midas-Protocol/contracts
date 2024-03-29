// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { AaveV3ERC4626 } from "../../midas/strategies/AaveV3ERC4626.sol";
import { AaveV3TestConfigStorage } from "./AaveV3TestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import "./AaveV3ERC4626Test.sol";

contract AaveV3AssetTest is AbstractAssetTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    test = AbstractERC4626Test(address(new AaveV3ERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new AaveV3TestConfigStorage()));
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

  // function testAccumulatingRewardsOnDeposit() public {
  //   this.runTest(AaveV3ERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  // }

  // function testAccumulatingRewardsOnWithdrawal() public {
  //   this.runTest(AaveV3ERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  // }

  // function testClaimRewards() public {
  //   this.runTest(AaveV3ERC4626Test(address(test)).testClaimRewards);
  // }
}
