// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "../../midas/AddressesProvider.sol";

abstract contract BaseTest is Test {
  uint256 constant BSC_MAINNET = 56;
  uint256 constant MOONBEAM_MAINNET = 1284;
  uint256 constant POLYGON_MAINNET = 137;
  uint256 constant ARBITRUM_ONE = 42161;

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
      ap = AddressesProvider(0xd4D0cA503E8befAbE4b75aAC36675Bc1cFA533D1);
    } else if (block.chainid == ARBITRUM_ONE) {
      ap = AddressesProvider(0xe693a13526Eb4cff15EbeC54779Ea640E2F36a9f);
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

  modifier shouldRunTestFail(bool run) {
    require(run, "test should fail");
    _;
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

  function compareStrings(string memory a, string memory b) public view returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  function asArray(address value) public pure returns (address[] memory) {
    address[] memory array = new address[](1);
    array[0] = value;
    return array;
  }

  function asArray(bool value) public pure returns (bool[] memory) {
    bool[] memory array = new bool[](1);
    array[0] = value;
    return array;
  }

  function asArray(uint256 value) public pure returns (uint256[] memory) {
    uint256[] memory array = new uint256[](1);
    array[0] = value;
    return array;
  }
}
