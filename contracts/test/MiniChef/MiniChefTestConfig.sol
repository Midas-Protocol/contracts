// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct MiniChefTestConfig {
  address asset;
  address rewardToken;
  uint256 poolId;
}

contract MiniChefTestConfigStorage is ITestConfigStorage {
  MiniChefTestConfig[] internal testConfigs;

  constructor() {
    // WEVMOS/DIFF
    testConfigs.push(
      MiniChefTestConfig(0x932c2D21fa11A545554301E5E6FB48C3accdFF4D, 0xD4949664cD82660AaE99bEdc034a0deA8A0bd517, 1)
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].rewardToken, testConfigs[i].poolId);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
