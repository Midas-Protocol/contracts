// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "../../utils/AddressesProvider.sol";

abstract contract BaseTest is Test {
  uint256 constant BSC_MAINNET = 56;
  uint256 constant MOONBEAM_MAINNET = 1284;

  uint256 constant EVMOS_TESTNET = 9000;
  uint256 constant BSC_CHAPEL = 97;

  AddressesProvider public ap = AddressesProvider(0x01c97299b37E66c03419bC4Db24074a89FB36e6d);

  constructor() {
    // TODO remove the config code
    // when there is an on-chain AddressesProvider instance to use
    configureAddressesProvider();
  }

  function configureAddressesProvider() internal {
    if (ap.owner() == address(0)) {
      ap.initialize(address(this));
    }
  }

  modifier shouldRun(bool run) {
    if (run) {
      _;
    }
  }

  function forChains(uint256 id0) public view returns (bool) {
    return block.chainid == id0;
  }

  function forChains(uint256 id0, uint256 id1) public view returns (bool) {
    return block.chainid == id0 || block.chainid == id1;
  }

  function diff(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a > b) {
      return a - b;
    } else {
      return b - a;
    }
  }
}
