// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct ThenaTestConfig {
  address asset;
}

contract ThenaTestConfigStorage is ITestConfigStorage {
  ThenaTestConfig[] internal testConfigs;

  constructor() {
    // HAY-BUSD
    testConfigs.push(ThenaTestConfig(0x93B32a8dfE10e9196403dd111974E325219aec24));
    // Algebra (Gamma) USDC-USDC
    testConfigs.push(ThenaTestConfig(0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2));
    // // Algebra THE-WBNB
    // testConfigs.push(
    //   ThenaTestConfig(0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2, 0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2)
    // );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
