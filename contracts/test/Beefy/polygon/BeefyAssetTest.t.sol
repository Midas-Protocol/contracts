// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { BeefyERC4626Test } from "../BeefyERC4626Test.sol";
import { BeefyTestConfig, BeefyPolygonTestConfigStorage } from "./BeefyTestConfig.sol";
import { MidasERC4626, BeefyERC4626, IBeefyVault } from "../../../midas/strategies/BeefyERC4626.sol";
import { AbstractAssetTest } from "../../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../../abstracts/ITestConfigStorage.sol";

interface IBeefyStrategy {
  function owner() external returns (address);

  function setHarvestOnDeposit(bool) external;
}

contract BeefyPolygonAssetTest is AbstractAssetTest {
  address lpChef = 0x2FAe83B3916e1467C970C113399ee91B31412bCD;

  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    test = new BeefyERC4626Test();
    testConfigStorage = ITestConfigStorage(address(new BeefyPolygonTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address beefyVault, uint256 withdrawalFee) = abi.decode(testConfig, (address, uint256));

    // Polygon beefy strategy has harvest on deposit option so set it false to make sure the deposit works properly.
    IBeefyStrategy strategy = IBeefyStrategy(IBeefyVault(beefyVault).strategy());
    vm.prank(strategy.owner());
    strategy.setHarvestOnDeposit(false);

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
