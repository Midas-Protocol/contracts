// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;

// import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

// struct AutofarmTestConfig {
//   address asset;
//   uint256 poolId;
// }

// contract AutofarmTestConfigStorage is ITestConfigStorage {
//   AutofarmTestConfig[] internal testConfigs;

//   constructor() {
//     // PAR/USDC
//     testConfigs.push(
//       AutofarmTestConfig(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 2)
//     );
//   }

//   function getTestConfig(uint256 i) public view returns (bytes memory) {
//     return abi.encode(testConfigs[i].asset, testConfigs[i].poolId);
//   }

//   function getTestConfigLength() public view returns (uint256) {
//     return testConfigs.length;
//   }
// }
