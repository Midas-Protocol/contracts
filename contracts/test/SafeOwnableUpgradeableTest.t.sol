// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import "../midas/SafeOwnableUpgradeable.sol";

contract SomeOwnable is SafeOwnableUpgradeable {
  function initialize() public initializer {
    __Ownable_init();
  }
}

contract SafeOwnableUpgradeableTest is BaseTest {
  function testSafeOwnableUpgradeable() public {
    SomeOwnable someOwnable = new SomeOwnable();
    someOwnable.initialize();

    address joe = address(1234);

    address initOwner = someOwnable.owner();
    assertEq(initOwner, address(this), "owner init value");

    vm.expectRevert("not used anymore");
    someOwnable.transferOwnership(joe);

    vm.expectRevert("not used anymore");
    someOwnable.renounceOwnership();

    someOwnable._setPendingOwner(joe);

    address currentOwner = someOwnable.owner();
    assertEq(currentOwner, address(this), "owner should not change yet");

    vm.prank(joe);
    someOwnable._acceptOwner();

    address ownerAfter = someOwnable.owner();

    assertEq(ownerAfter, joe, "ownership transfer failed");
  }
}
