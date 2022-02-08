pragma solidity ^0.7.6;

// SPDX-License-Identifier: UNLICENSED

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import "../contracts/FusePoolDirectory.sol";

contract FusePoolDirectoryTest is DSTest {
  using stdStorage for StdStorage;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  StdStorage stdstore;

  FusePoolDirectory fusePoolDirectory;

  function setUp() public {
    fusePoolDirectory = new FusePoolDirectory();
  }

  function testInitialize() public {
    address[] memory addresses = new address[](2); 
    addresses[0] = address(0); 
    addresses[1] = address(1);
    fusePoolDirectory.initialize(true, addresses);
  }
}
