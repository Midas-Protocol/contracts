// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

struct WombatTestConfig {
  address asset;
  address vault;
  ERC20Upgradeable[] rewardTokens;
}

contract WombatTestConfigStorage is ITestConfigStorage {
  WombatTestConfig[] internal testConfigs;

  constructor() {
    // wmxLP-WBNB
    ERC20Upgradeable[] memory _rewardTokens = new ERC20Upgradeable[](2);
    _rewardTokens[0] = ERC20Upgradeable(0xAD6742A35fB341A9Cc6ad674738Dd8da98b94Fb1); // WOM
    _rewardTokens[1] = ERC20Upgradeable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); // WBNB

    testConfigs.push(
      WombatTestConfig(
        0x74f019A5C4eD2C2950Ce16FaD7Af838549092c5b,
        0x98C8f6f029E3A19D796Eb16f9c24703ad884cC83,
        _rewardTokens
      )
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].asset, testConfigs[i].vault, testConfigs[i].rewardTokens);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
