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
    // ATOM/GLMR
    address[] memory rewardTokens = new address[](2);
    rewardTokens[0] = 0x0E358838ce72d5e61E0018a2ffaC4bEC5F4c88d2; // STELLA token
    rewardTokens[1] = 0xAcc15dC74880C9944775448304B263D191c6077F; // WGLMR token

    testConfigs.push(StellaTestConfig(0x8CCBbcAF58f5422F6efD4034d8E8a3c9120ADf79, 28, rewardTokens)); // USDC-WGLMR
    testConfigs.push(StellaTestConfig(0xf8f5E8B9Ee84664695B14862212D8092E16331F6, 30, rewardTokens)); // WBTC-WGLMR
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].poolId, testConfigs[i].rewardTokens);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
