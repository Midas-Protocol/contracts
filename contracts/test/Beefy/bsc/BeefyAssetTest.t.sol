// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../helpers/WithPool.sol";
import "../../config/BaseTest.t.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { BeefyERC4626Test } from "../BeefyERC4626Test.sol";
import { BeefyTestConfig, BeefyBscTestConfigStorage } from "./BeefyTestConfig.sol";
import { MidasERC4626, BeefyERC4626, IBeefyVault } from "../../../midas/strategies/BeefyERC4626.sol";
import { AbstractAssetTest } from "../../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../../abstracts/ITestConfigStorage.sol";

contract BeefyBscAssetTest is AbstractAssetTest {
  address lpChef = 0x1083926054069AaD75d7238E9B809b0eF9d94e5B;

  constructor() {
    test = AbstractERC4626Test(address(new BeefyERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new BeefyBscTestConfigStorage()));
    shouldRunTest = forChains(BSC_MAINNET);
  }

  function setUp() public override shouldRun(shouldRunTest) {}

  function setUpTestContract(bytes calldata testConfig) public override shouldRun(shouldRunTest) {
    (address beefyVault, uint256 withdrawalFee) = abi.decode(testConfig, (address, uint256));

    test.setUp(
      MockERC20(address(IBeefyVault(beefyVault).want())).symbol(),
      abi.encode(beefyVault, withdrawalFee, lpChef, shouldRunTest)
    );
  }

  function testInitializedValues() public override shouldRun(shouldRunTest) {
    for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
      bytes memory testConfig = testConfigStorage.getTestConfig(i);

      this.setUpTestContract(testConfig);

      (address beefyVault, ) = abi.decode(testConfig, (address, uint256));

      MockERC20 asset = MockERC20(address(IBeefyVault(beefyVault).want()));

      test.testInitializedValues(asset.name(), asset.symbol());
    }
  }
}
