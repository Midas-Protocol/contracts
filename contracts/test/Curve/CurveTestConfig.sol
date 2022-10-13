// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct CurveTestConfig {
  address gauge;
  address asset;
  address[] rewardsToken;
}

contract CurveTestConfigStorage is ITestConfigStorage {
  CurveTestConfig[] internal testConfigs;
  address[] internal tempRewardsToken;

  constructor() {
    // Matic/stMatic
    tempRewardsToken.push(0xC3C7d422809852031b44ab29EEC9F1EfF2A58756); // LDO
    testConfigs.push(
      CurveTestConfig(
        0x9633E0749faa6eC6d992265368B88698d6a93Ac0, // Matic/stMatic Gauge
        0xe7CEA2F6d7b120174BF3A9Bc98efaF1fF72C997d, // Matic/stMatic LpToken
        tempRewardsToken
      )
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].gauge, testConfigs[i].asset, testConfigs[i].rewardsToken);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
