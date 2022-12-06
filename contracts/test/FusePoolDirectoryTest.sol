// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { FusePoolDirectory } from "../FusePoolDirectory.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract FusePoolDirectoryTest is BaseTest {
  function testDeprecatePool() public fork(BSC_MAINNET) {
    _testDeprecatePool();
  }

  function _testDeprecatePool() internal {
    address fpdAddress = ap.getAddress("FusePoolDirectory");
    FusePoolDirectory fpd = FusePoolDirectory(fpdAddress);

    // upgrade
    {
      bytes32 _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
      FusePoolDirectory newImpl = new FusePoolDirectory();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(fpdAddress));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      // emit log_address(admin);
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    FusePoolDirectory.FusePool[] memory allPools = fpd.getAllPools();

    FusePoolDirectory.FusePool memory poolToDeprecate;
    uint256 index;
    if (allPools.length > 3) {
      index = allPools.length - 2;
    } else {
      index = 0;
    }

    poolToDeprecate = allPools[index];

    vm.prank(fpd.owner());
    fpd._deprecatePool(index);

    FusePoolDirectory.FusePool[] memory allPoolsAfter = fpd.getAllPools();

    assertTrue(allPoolsAfter[index].comptroller != poolToDeprecate.comptroller, "!deprecate");
  }
}
