pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "../gauges/VeMDSToken.sol";

contract TOUCHToken is ERC20 {
  mapping(address => uint256) public stakingStartedTime;
  mapping(address => uint256) public stakes;
  address public totalStaked;
  VeMDSToken veToken;

  constructor(uint256 _initialSupply, VeMDSToken _veToken) ERC20("Midas TOUCH Token", "TOUCH", 18) {
    _mint(msg.sender, _initialSupply);
    veToken = _veToken;
  }

  function stake(uint256 amount) public {
    transferFrom(msg.sender, address(this), amount);
    stakingStartedTime[msg.sender] = block.timestamp;
    stakes[msg.sender] = amount;
    totalStaked += amount;

    uint256 maxCurrentVotingPower = votingPowerOf(msg.sender);
    uint256 currentBalanceOfVeTokens = veToken.balanceOf(msg.sender);
    uint256 amountToMint = maxCurrentVotingPower - currentBalanceOfVeTokens;

    veToken.mint(msg.sender, amountToMint);
  }

  function unstake(uint256 amount) public {
    stakingStartedTime[msg.sender] = 0;// ?
  }

  function votingPowerOf(address account) public view returns (uint) {
    uint stakingStartedTime = stakingStartedTime[account];
    if (stakingStartedTime == 0) {
      return 0;
    } else {
      uint _stake = stakes[account];
      uint hoursSinceStaked = (block.timestamp - stakingStartedTime) % 3600;
      if (hoursSinceStaked < 7143) { // 7143 * 0.014 = 100.002
        // percentage unlocked = hours since staked * 0.014
        return (_stake * hoursSinceStaked * 14) / 100000;
      } else {
        // 298 * 24 = 7152
        // during day 298 voting power becomes 100% of the staked MDS
        return _stake;
      }
    }
  }
}
