// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct HelioTestConfig {
  address asset;
  address jar;
}

contract HelioTestConfigStorage is ITestConfigStorage {
  HelioTestConfig[] internal testConfigs;

  constructor() {
    // HAY
    testConfigs.push(
      HelioTestConfig(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5, 0x0a1Fd12F73432928C190CAF0810b3B767A59717e)
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].jar);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
