// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct EllipsisTestConfig {
  address asset;
}

contract EllipsisTestConfigStorage is ITestConfigStorage {
  EllipsisTestConfig[] internal testConfigs;

  constructor() {
    // BUSD/USDD
    testConfigs.push(
      EllipsisTestConfig(0xB343F4cDE5e2049857898E800CD385247e21836D)
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
