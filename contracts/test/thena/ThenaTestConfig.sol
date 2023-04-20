// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct ThenaTestConfig {
  address asset;
  address assetWhale;
}

contract ThenaTestConfigStorage is ITestConfigStorage {
  ThenaTestConfig[] internal testConfigs;

  constructor() {
    // HAY-BUSD
    testConfigs.push(
      ThenaTestConfig(0x93B32a8dfE10e9196403dd111974E325219aec24, 0xE43317c1f037CBbaF33F33C386f2cAF2B6b25C9C)
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].assetWhale);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}