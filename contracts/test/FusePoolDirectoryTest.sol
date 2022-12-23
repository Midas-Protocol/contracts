// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { FusePoolDirectory } from "../FusePoolDirectory.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract FusePoolDirectoryTest is BaseTest {
  FusePoolDirectory fpd;

  function afterForkSetUp() internal override {
    address fpdAddress = ap.getAddress("FusePoolDirectory");
    fpd = FusePoolDirectory(fpdAddress);

    // upgrade to the current changes impl
    {
      FusePoolDirectory newImpl = new FusePoolDirectory();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(fpdAddress));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }
  }

  function testDeprecatePool() public fork(BSC_MAINNET) {
    _testDeprecatePool();
  }

  function _testDeprecatePool() internal {
    (, FusePoolDirectory.FusePool[] memory allPools) = fpd.getActivePools();

    FusePoolDirectory.FusePool memory poolToDeprecate;
    uint256 index;
    if (allPools.length > 3) {
      index = allPools.length - 1;
    } else {
      index = 0;
    }

    poolToDeprecate = allPools[index];

    vm.prank(fpd.owner());
    fpd._deprecatePool(index);

    (, FusePoolDirectory.FusePool[] memory allPoolsAfter) = fpd.getActivePools();

    bool poolStillThere = false;
    for (uint256 i = 0; i < allPoolsAfter.length; i++) {
      if (allPoolsAfter[i].comptroller == poolToDeprecate.comptroller) {
        poolStillThere = true;
        break;
      }
    }

    assertTrue(!poolStillThere, "deprecated pool is still there");
  }

  function testQPool() public fork(BSC_MAINNET) {
    fpd = FusePoolDirectory(0x295d7347606F4bd810C8296bb8d75D657001fcf7);
    FusePoolDirectory.FusePool[] memory allPools = fpd.getAllPools();
    (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory allPoolsAfter) = fpd.getActivePools();
    for (uint256 i = 0; i < allPoolsAfter.length; i++) {
      emit log_named_address("comp", allPoolsAfter[i].comptroller);
      emit log_named_uint("idx", indexes[i]);
    }
  }
}
