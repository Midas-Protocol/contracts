// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "../../utils/AddressesProvider.sol";

abstract contract BaseTest is Test {
  uint256 constant BSC_MAINNET = 56;
  uint256 constant MOONBEAM_MAINNET = 1284;
  uint256 constant POLYGON_MAINNET = 137;

  uint256 constant EVMOS_TESTNET = 9000;
  uint256 constant BSC_CHAPEL = 97;
  uint256 constant NEON_DEVNET = 245022926;

  AddressesProvider public ap;

  constructor() {
    if (block.chainid == BSC_MAINNET) {
      ap = AddressesProvider(0x01c97299b37E66c03419bC4Db24074a89FB36e6d);
    } else if (block.chainid == BSC_CHAPEL) {
      ap = AddressesProvider(0x38742363597fBaE312B0bdcC351fCc6107E9E27E);
    } else if (block.chainid == MOONBEAM_MAINNET) {
      ap = AddressesProvider(0x771ee5a72A57f3540E5b9A6A8C226C2a24A70Fae);
    } else if (block.chainid == EVMOS_TESTNET) {
      ap = AddressesProvider(0xB88C6a114F01a80Dc8465b55067C8D046C2F445A);
    } else if (block.chainid == POLYGON_MAINNET) {
      ap = AddressesProvider(0x2fCa24E19C67070467927DDB85810fF766423e8e);
    } else if (block.chainid == NEON_DEVNET) {
      ap = AddressesProvider(0xC4b1512c1eeDd272e0F68737aCd7a1F11F3cA0eF);
    } else {
      ap = new AddressesProvider();
    }
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
