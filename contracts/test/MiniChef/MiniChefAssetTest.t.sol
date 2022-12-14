// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MiniChefERC4626, IMiniChefV2, IRewarder } from "../../midas/strategies/MiniChefERC4626.sol";
import { MiniChefTestConfigStorage } from "./MiniChefTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import "./MiniChefERC4626Test.sol";

contract MiniChefAssetTest is AbstractAssetTest {
  function setUp() public fork(EVMOS_MAINNET) {}

  IMiniChefV2 miniChef = IMiniChefV2(0x067eC87844fBD73eDa4a1059F30039584586e09d);

  function afterForkSetUp() internal override {
    test = AbstractERC4626Test(address(new MiniChefERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new MiniChefTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address asset, address[] memory rewardTokens, uint256 poolId) = abi.decode(
      testConfig,
      (address, address[], uint256)
    );

    test.setUpWithPool(MasterPriceOracle(ap.getAddress("MasterPriceOracle")), ERC20Upgradeable(asset));

    test._setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override {
    if (shouldRunForChain(block.chainid)) {
      for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
        bytes memory testConfig = testConfigStorage.getTestConfig(i);

        this.setUpTestContract(testConfig);

        (address asset, , ) = abi.decode(testConfig, (address, address[], uint256));

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
    this.runTest(MiniChefERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    this.runTest(MiniChefERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  }

  function testClaimRewards() public {
    this.runTest(MiniChefERC4626Test(address(test)).testClaimRewards);
  }
}
