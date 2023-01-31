// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../../abstracts/ITestConfigStorage.sol";

struct BeefyTestConfig {
  address beefyVault;
  uint256 withdrawalFee;
}

contract BeefyBscTestConfigStorage is ITestConfigStorage {
  BeefyTestConfig[] internal testConfigs;

  constructor() {
    // CAKE-BNB LP
    testConfigs.push(BeefyTestConfig(0xb26642B6690E4c4c9A6dAd6115ac149c700C7dfE, 10));

    // BUSD-BNB LP
    testConfigs.push(BeefyTestConfig(0xAd61143796D90FD5A61d89D63a546C7dB0a70475, 10));

    // BTCB-ETH LP
    testConfigs.push(BeefyTestConfig(0xEf43E54Bb4221106953951238FC301a1f8939490, 10));

    // ETH-BNB LP
    testConfigs.push(BeefyTestConfig(0x0eb78598851D08218d54fCe965ee2bf29C288fac, 10));

    // USDC-BUSD LP
    testConfigs.push(BeefyTestConfig(0x9260c62866f36638964551A8f480C3aAAa4693fd, 10));
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].beefyVault, testConfigs[i].withdrawalFee);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
