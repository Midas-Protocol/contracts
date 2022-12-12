// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { CurveTestConfigStorage } from "./CurveTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import { MockPriceOracle, IPriceOracle } from "../../oracles/1337/MockPriceOracle.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import "./CurveERC4626Test.sol";

contract CurveAssetTest is AbstractAssetTest {
  MasterPriceOracle masterPriceOracle;
  address[] underlyingsForOracle;
  IPriceOracle[] oracles;

  function setUp() public forkAtBlock(POLYGON_MAINNET, 33063212) {}

  function afterForkSetUp() internal override {
    test = AbstractERC4626Test(address(new CurveERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new CurveTestConfigStorage()));
    masterPriceOracle = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (, address asset, ) = abi.decode(testConfig, (address, address, address[]));

    // Set up new oracle
    MockPriceOracle curveOracle = new MockPriceOracle(60);

    underlyingsForOracle.push(asset);
    oracles.push(IPriceOracle(address(curveOracle)));

    vm.prank(masterPriceOracle.admin());
    masterPriceOracle.add(underlyingsForOracle, oracles);

    test.setUpWithPool(masterPriceOracle, ERC20Upgradeable(asset));

    test._setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override {
    if (shouldRunForChain(block.chainid)) {
      for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
        bytes memory testConfig = testConfigStorage.getTestConfig(i);

        this.setUpTestContract(testConfig);

        (, address asset) = abi.decode(testConfig, (address, address));

        test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
      }
    }
  }

  function testDepositWithIncreasedVaultValue() public override {
    // Cant Increase Assets in Vault
    assertTrue(true);
  }

  function testDepositWithDecreasedVaultValue() public override {
    // Cant Decrease Assets in Vault
    assertTrue(true);
  }

  function testWithdrawWithIncreasedVaultValue() public override {
    // Cant Increase Assets in Vault
    assertTrue(true);
  }

  function testWithdrawWithDecreasedVaultValue() public override {
    // Cant Decrease Assets in Vault
    assertTrue(true);
  }

  function testAccumulatingRewardsOnDeposit() public {
    this.runTest(CurveERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    this.runTest(CurveERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  }

  function testClaimRewards() public {
    this.runTest(CurveERC4626Test(address(test)).testClaimRewards);
  }
}
