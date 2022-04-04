// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../compound/CToken.sol";
import "./VeMDSToken.sol";
import "./GaugesController.sol";

contract Gauge {
  GaugesController public gaugesController;
  VeMDSToken private veMdsToken;
  CToken public cToken;
  IRewardsDistributor public rewardsDistributor;
}
