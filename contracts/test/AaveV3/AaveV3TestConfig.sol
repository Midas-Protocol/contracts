// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct AaveV3TestConfig {
  address asset;
}

contract AaveV3TestConfigStorage is ITestConfigStorage {
  AaveV3TestConfig[] internal testConfigs;

  constructor() {
    // WMATIC
    testConfigs.push(AaveV3TestConfig(0xa3Fa99A148fA48D14Ed51d610c367C61876997F1));
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
