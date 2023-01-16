// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

contract Utils {
  function diff(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a > b) {
      return a - b;
    } else {
      return b - a;
    }
  }

  function compareStrings(string memory a, string memory b) public pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  function asArray(address value) public pure returns (address[] memory) {
    address[] memory array = new address[](1);
    array[0] = value;
    return array;
  }

  function asArray(address value0, address value1) public pure returns (address[] memory) {
    address[] memory array = new address[](2);
    array[0] = value0;
    array[1] = value1;
    return array;
  }

  function asArray(address value0, address value1, address value2, address value3) public pure returns (address[] memory) {
    address[] memory array = new address[](4);
    array[0] = value0;
    array[1] = value1;
    array[2] = value2;
    array[3] = value3;
    return array;
  }

  function asArray(address value0, address value1, address value2, address value3, address value4) public pure returns (address[] memory) {
    address[] memory array = new address[](5);
    array[0] = value0;
    array[1] = value1;
    array[2] = value2;
    array[3] = value3;
    array[4] = value4;
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

  function asArray(uint256 value0, uint256 value1) public pure returns (uint256[] memory) {
    uint256[] memory array = new uint256[](2);
    array[0] = value0;
    array[1] = value1;
    return array;
  }

  function asArray(uint256 value0, uint256 value1, uint256 value2, uint256 value3) public pure returns (uint256[] memory) {
    uint256[] memory array = new uint256[](4);
    array[0] = value0;
    array[1] = value1;
    array[2] = value2;
    array[3] = value3;
    return array;
  }

  function asArray2(uint256 value0, uint256 value1) public pure returns (uint256[2] memory) {
    uint256[2] memory array;
    array[0] = value0;
    array[1] = value1;
    return array;
  }

  function asArray(bytes memory value) public pure returns (bytes[] memory) {
    bytes[] memory array = new bytes[](1);
    array[0] = value;
    return array;
  }

  function asArray(bytes memory value0, bytes memory value1) public pure returns (bytes[] memory) {
    bytes[] memory array = new bytes[](2);
    array[0] = value0;
    array[1] = value1;
    return array;
  }

  function asArray(
    bytes memory value0,
    bytes memory value1,
    bytes memory value2
  ) public pure returns (bytes[] memory) {
    bytes[] memory array = new bytes[](3);
    array[0] = value0;
    array[1] = value1;
    array[2] = value2;
    return array;
  }
}
