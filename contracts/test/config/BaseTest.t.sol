// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "../../midas/AddressesProvider.sol";

abstract contract BaseTest is Test {
  AddressesProvider public ap;

  function compareNetwork(string memory str1, string memory str2) internal returns (bool) {
    return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
  }

  function setAddressProvider(string memory network) internal {
    if (compareNetwork(network, "bsc")) {
      ap = AddressesProvider(0x01c97299b37E66c03419bC4Db24074a89FB36e6d);
    } else if (compareNetwork(network, "bsc_chapel")) {
      ap = AddressesProvider(0x38742363597fBaE312B0bdcC351fCc6107E9E27E);
    } else if (compareNetwork(network, "moonbeam")) {
      ap = AddressesProvider(0x771ee5a72A57f3540E5b9A6A8C226C2a24A70Fae);
    } else if (compareNetwork(network, "evmos_test")) {
      ap = AddressesProvider(0xB88C6a114F01a80Dc8465b55067C8D046C2F445A);
    } else if (compareNetwork(network, "polygon")) {
      ap = AddressesProvider(0x2fCa24E19C67070467927DDB85810fF766423e8e);
    } else if (compareNetwork(network, "neon_dev")) {
      ap = AddressesProvider(0xd4D0cA503E8befAbE4b75aAC36675Bc1cFA533D1);
    } else if (compareNetwork(network, "arbitrum")) {
      ap = AddressesProvider(0xe693a13526Eb4cff15EbeC54779Ea640E2F36a9f);
    } else {
      ap = new AddressesProvider();
    }
    configureAddressesProvider();
  }

  function createSelectFork(string memory network, uint256 forkBlockNumber) internal returns (uint256) {
    uint256 forkId = vm.createSelectFork(vm.rpcUrl(network), forkBlockNumber);
    return forkId;
  }

  function createFork(string memory network, uint256 forkBlockNumber) internal returns (uint256) {
    uint256 forkId = vm.createFork(vm.rpcUrl(network), forkBlockNumber);
    return forkId;
  }

  function configureAddressesProvider() internal {
    if (ap.owner() == address(0)) {
      ap.initialize(address(this));
    }
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
