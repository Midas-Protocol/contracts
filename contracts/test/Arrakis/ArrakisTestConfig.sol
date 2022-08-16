// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct ArrakisTestConfig {
  address pool;
  address asset;
}

contract ArrakisTestConfigStorage is ITestConfigStorage {
  ArrakisTestConfig[] internal testConfigs;

  constructor() {
    // PAR/USDC
    
    testConfigs.push(
      ArrakisTestConfig(0x528330fF7c358FE1bAe348D23849CCed8edA5917, 0xC1DF4E2fd282e39346422e40C403139CD633Aacd)
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].pool);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
