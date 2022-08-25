// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct StellaTestConfig {
  address asset;
  uint256 poolId;
  address[] rewardTokens;
}

contract StellaTestConfigStorage is ITestConfigStorage {
  StellaTestConfig[] internal testConfigs;

  constructor() {
    // 2JBRL
    address[] memory rewardTokens = new address[](2);
    rewardTokens[0] = 0x0E358838ce72d5e61E0018a2ffaC4bEC5F4c88d2; // STELLA token
    rewardTokens[1] = 0x3795C36e7D12A8c252A20C5a7B455f7c57b60283; // CLEAR token

    testConfigs.push(
      StellaTestConfig(0x2f6F833fAb26Bf7F81827064f67ea4844BdEa03F, 0, rewardTokens)
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].poolId, testConfigs[i].rewardTokens);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
