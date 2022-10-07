// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct DotDotTestConfig {
  address masterPriceOracle;
  address asset;
}

contract DotDotTestConfigStorage is ITestConfigStorage {
  DotDotTestConfig[] internal testConfigs;

  constructor() {
    // 2JBRL
    testConfigs.push(
      DotDotTestConfig(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA, 0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9)
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].masterPriceOracle, testConfigs[i].asset);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
