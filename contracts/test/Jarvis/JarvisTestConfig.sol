// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct JarvisTestConfig {
  address vault;
  address asset;
}

contract JarvisTestConfigStorage is ITestConfigStorage {
  JarvisTestConfig[] internal testConfigs;

  constructor() {
    // PAR/jEUR

    testConfigs.push(
      JarvisTestConfig(0x2BC39d179FAfC32B7796DDA3b936e491C87D245b, 0x0f110c55EfE62c16D553A3d3464B77e1853d0e97)
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].vault);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
