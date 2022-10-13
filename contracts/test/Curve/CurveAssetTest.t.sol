// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { CurveERC4626Test } from "./CurveERC4626Test.sol";
import { CurveTestConfig, CurveTestConfigStorage } from "./CurveTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import { MockPriceOracle, IPriceOracle } from "../../oracles/1337/MockPriceOracle.sol";

contract CurveAssetTest is AbstractAssetTest {
  address masterPriceOracle;
  address[] underlyingsForOracle;
  IPriceOracle[] oracles;

  constructor() {
    test = AbstractERC4626Test(address(new CurveERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new CurveTestConfigStorage()));
    shouldRunTest = forChains(POLYGON_MAINNET);
  }

  function setUp() public override shouldRun(shouldRunTest) {
    masterPriceOracle = ap.getAddress("MasterPriceOracle");
  }

  function setUpTestContract(bytes calldata testConfig) public override shouldRun(shouldRunTest) {
    (, address asset, ) = abi.decode(testConfig, (address, address, address[]));

    // Set up new oracle
    MockPriceOracle curveOracle = new MockPriceOracle(60);

    underlyingsForOracle.push(asset);
    oracles.push(IPriceOracle(address(curveOracle)));

    vm.prank(MasterPriceOracle(masterPriceOracle).admin());
    MasterPriceOracle(masterPriceOracle).add(underlyingsForOracle, oracles);

    test.setUpWithPool(MasterPriceOracle(masterPriceOracle), ERC20Upgradeable(asset));

    test.setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override shouldRun(shouldRunTest) {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      bytes memory testConfig = testConfigStorage.getTestConfig(i);

      this.setUpTestContract(testConfig);

      (, address asset) = abi.decode(testConfig, (address, address));

      test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
    }
  }

  function testDepositWithIncreasedVaultValue() public override shouldRun(false) {
    // Cant Increase Assets in Vault
    assertTrue(true);
  }

  function testDepositWithDecreasedVaultValue() public override shouldRun(false) {
    // Cant Decrease Assets in Vault
    assertTrue(true);
  }

  function testWithdrawWithIncreasedVaultValue() public override shouldRun(false) {
    // Cant Increase Assets in Vault
    assertTrue(true);
  }

  function testWithdrawWithDecreasedVaultValue() public override shouldRun(false) {
    // Cant Decrease Assets in Vault
    assertTrue(true);
  }

  function testAccumulatingRewardsOnDeposit() public shouldRun(shouldRunTest) {
    this.runTest(CurveERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  }

  function testAccumulatingRewardsOnWithdrawal() public shouldRun(shouldRunTest) {
    this.runTest(CurveERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  }

  function testClaimRewards() public shouldRun(shouldRunTest) {
    this.runTest(CurveERC4626Test(address(test)).testClaimRewards);
  }
}
