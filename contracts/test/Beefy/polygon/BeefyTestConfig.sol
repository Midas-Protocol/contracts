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
    // agEUR-jEUR LP
    testConfigs.push(BeefyTestConfig(0x5F1b5714f30bAaC4Cb1ee95E1d0cF6d5694c2204, 10));

    // jEUR-PAR LP
    testConfigs.push(BeefyTestConfig(0xfE1779834EaDD60660a7F3f576448D6010f5e3Fc, 10));

    // jJPY-JPYC LP
    testConfigs.push(BeefyTestConfig(0x122E09FdD2FF73C8CEa51D432c45A474BAa1518a, 10));

    // jCAD-CADC LP
    testConfigs.push(BeefyTestConfig(0xcf9Dd1de1D02158B3d422779bd5184032674A6D1, 10));

    // jSGD-XSGD LP
    testConfigs.push(BeefyTestConfig(0x18DAdac6d0AAF37BaAAC811F6338427B46815a81, 10));
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].beefyVault, testConfigs[i].withdrawalFee);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
