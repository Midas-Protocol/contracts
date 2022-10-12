// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct CurveTestConfig {
  address masterPriceOracle;
  address gauge;
  address asset;
  address[] rewardsToken;
}

contract CurveTestConfigStorage is ITestConfigStorage {
  CurveTestConfig[] internal testConfigs;
  address[] internal tempRewardsToken;

  constructor() {
    // DOTSTDOT-f
    tempRewardsToken.push(0x9Fda7cEeC4c18008096C2fE2B85F05dc300F94d0); // LDO
    testConfigs.push(
      CurveTestConfig(
        0x14C15B9ec83ED79f23BF71D51741f58b69ff1494,
        0xC106C836771B0B4f4a0612Bd68163Ca93be1D340,
        0xc6e37086D09ec2048F151D11CdB9F9BbbdB7d685,
        tempRewardsToken
      )
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].gauge, testConfigs[i].asset, testConfigs[i].rewardsToken);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
