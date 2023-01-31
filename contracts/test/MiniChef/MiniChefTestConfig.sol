// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct MiniChefTestConfig {
  address asset;
  address[] rewardTokens;
  uint256 poolId;
}

contract MiniChefTestConfigStorage is ITestConfigStorage {
  MiniChefTestConfig[] internal testConfigs;

  constructor() {
    // WEVMOS/gUSDC

    address[] memory rewardTokens = new address[](1);
    rewardTokens[0] = 0x3f75ceabCDfed1aCa03257Dc6Bdc0408E2b4b026;

    testConfigs.push(MiniChefTestConfig(0xD7bfB11ED8fd924E77487480d13542328601e5a3, rewardTokens, 7));
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].rewardTokens, testConfigs[i].poolId);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
