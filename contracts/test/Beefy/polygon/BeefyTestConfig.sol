// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../../abstracts/ITestConfigStorage.sol";

struct BeefyTestConfig {
  address beefyVault;
  uint256 withdrawalFee;
}

contract BeefyPolygonTestConfigStorage is ITestConfigStorage {
  BeefyTestConfig[] internal testConfigs;

  constructor() {
    // StMatic-bbaWMATIC Stable BLP using https://app.dyson.money/#/pools?id=balancer-stmatic-bbawmatic
    testConfigs.push(BeefyTestConfig(0x18661C2527220aBE021F5b52351d5c4210E0E2c6, 10));
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].beefyVault, testConfigs[i].withdrawalFee);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
