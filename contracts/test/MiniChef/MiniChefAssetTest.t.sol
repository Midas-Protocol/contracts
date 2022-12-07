// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MidasERC4626, MiniChefERC4626, IMiniChefV2, IRewarder } from "../../midas/strategies/MiniChefERC4626.sol";
import { MiniChefTestConfigStorage } from "./MiniChefTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import { IUniswapV2Factory } from "../../external/uniswap/IUniswapV2Factory.sol";
import "./MiniChefERC4626Test.sol";

contract MiniChefAssetTest is AbstractAssetTest {
  function afterForkSetUp() internal override {
    test = AbstractERC4626Test(address(new MiniChefERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new MiniChefTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address asset, address rewardToken, uint256 poolId) = abi.decode(testConfig, (address, address, uint256));

    test.setUpWithPool(MasterPriceOracle(ap.getAddress("MasterPriceOracle")), ERC20Upgradeable(asset));

    test.setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testGetMiniChefPool0() public fork(EVMOS_MAINNET) {
    IUniswapV2Factory factory = IUniswapV2Factory(0x6aBdDa34Fb225be4610a2d153845e09429523Cd2);
    emit log_uint(factory.allPairsLength());
    address pair = factory.getPair(0xD4949664cD82660AaE99bEdc034a0deA8A0bd517, 0x3f75ceabCDfed1aCa03257Dc6Bdc0408E2b4b026);

    emit log_address(pair);
  }

  function testInitializedValues() public override fork(EVMOS_MAINNET) {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      bytes memory testConfig = testConfigStorage.getTestConfig(i);

      this.setUpTestContract(testConfig);

      (address asset, ,) = abi.decode(testConfig, (address, address, uint256));

      test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
    }
  }

  // function testDepositWithIncreasedVaultValue() public override fork(POLYGON_MAINNET) {
  //   this.runTest(test.testDepositWithIncreasedVaultValue);
  // }

  // function testDepositWithDecreasedVaultValue() public override fork(POLYGON_MAINNET) {
  //   this.runTest(test.testDepositWithDecreasedVaultValue);
  // }

  // function testWithdrawWithIncreasedVaultValue() public override fork(POLYGON_MAINNET) {
  //   this.runTest(test.testWithdrawWithIncreasedVaultValue);
  // }

  // function testWithdrawWithDecreasedVaultValue() public override fork(POLYGON_MAINNET) {
  //   this.runTest(test.testWithdrawWithDecreasedVaultValue);
  // }

  // function testAccumulatingRewardsOnDeposit() public fork(POLYGON_MAINNET) {
  //   this.runTest(MiniChefERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  // }

  // function testAccumulatingRewardsOnWithdrawal() public fork(POLYGON_MAINNET) {
  //   this.runTest(MiniChefERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  // }

  // function testClaimRewards() public fork(POLYGON_MAINNET) {
  //   this.runTest(MiniChefERC4626Test(address(test)).testClaimRewards);
  // }
}
