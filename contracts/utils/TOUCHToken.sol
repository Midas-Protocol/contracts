pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "../gauges/VeMDSToken.sol";

contract TOUCHToken is ERC20 {
  mapping(address => uint256) public stakingStartedTime;
  mapping(address => uint256) internal _lockedStakes;
  mapping(address => uint256) internal _unlockedStakes;
  address public totalStaked;
  VeMDSToken veToken;

  constructor(uint256 _initialSupply, VeMDSToken _veToken) ERC20("Midas TOUCH Token", "TOUCH", 18) {
    _mint(msg.sender, _initialSupply);
    veToken = _veToken;
  }

  // needs to be called from time to time
  function claimAccumulatedVotingPower() external returns (uint256) {
    return _claimAccumulatedVotingPower();
  }

  // needs to be called from time to time?
  function _claimAccumulatedVotingPower() internal returns (uint256) {
    uint256 unlockedVotingPower = votingPowerOf(msg.sender);

    // update locked/unlocked state
    _lockedStakes[msg.sender] = _unlockedStakes[msg.sender] + _lockedStakes[msg.sender] - unlockedVotingPower;
    _unlockedStakes[msg.sender] = unlockedVotingPower;
    // totalStaked remains the same

    // mint the accumulated veTokens
    uint256 currentBalanceOfVeTokens = veToken.balanceOf(msg.sender);
    uint256 amountToMint = unlockedVotingPower - currentBalanceOfVeTokens;
    veToken.mint(msg.sender, amountToMint);

    return amountToMint;
  }

  function stake(uint256 amountToStake) public {
    // call first, then change the state
    // safe methods not needed?
    transferFrom(msg.sender, address(this), amountToStake);

    // unlock already usable voting power, lock the rest + new
    uint256 unlockedVotingPower = votingPowerOf(msg.sender); // =
    // update locked/unlocked state
    stakingStartedTime[msg.sender] = block.timestamp;
    _unlockedStakes[msg.sender] = unlockedVotingPower;
    // new locked + old locked - new unlocked
    _lockedStakes[msg.sender] = amountToStake + _lockedStakes[msg.sender] - unlockedVotingPower;
    totalStaked += amountToStake;

    // mint the accumulated voting power to voting escrow
    uint256 currentBalanceOfVeTokens = veToken.balanceOf(msg.sender);
    uint256 amountToMint = unlockedVotingPower - currentBalanceOfVeTokens;
    veToken.mint(msg.sender, amountToMint);

    // emit stakinng event
  }

  // TODO unstake proportionally from the locked and unlocked stake?
  function unstake(uint256 amountToUnstake) public {
    require(amountToUnstake <= _unlockedStakes[msg.sender] + _lockedStakes[msg.sender], "stake not enough");
    uint256 amountToReceive = amountToUnstake;
    //_claimAccumulatedVotingPower();

    // update locked/unlocked state
    totalStaked -= amountToStake;
    // first we unstake the unlocked part, then the locked
    if (_unlockedStakes[msg.sender] >= amountToUnstake) {
      _unlockedStakes[msg.sender] -= amountToUnstake;
      amountToUnstake = 0;
    } else {
      amountToUnstake -= _unlockedStakes[msg.sender];
      _unlockedStakes[msg.sender] = 0;
    }
    // if not enough, take from the locked part
    if (_lockedStakes[msg.sender] >= amountToUnstake) {
      _lockedStakes[msg.sender] -= amountToUnstake;
      amountToUnstake = 0;
    }

    // reset if no pending to be unlocked stake is left
    if (_lockedStakes[msg.sender] == 0) {
      stakingStartedTime[msg.sender] = 0;
    }

    // remove voting power from escrow
    veToken.burn(msg.sender, amountToReceive);

    // call transfer in the end, as the reentrancy protection pattern requires
    transfer(msg.sender, amountToReceive);

    // emit unstaking event
  }

  function votingPowerOf(address account) public view returns (uint vp) {
    uint stakingStartedTime = stakingStartedTime[account];
    if (stakingStartedTime == 0) {
      return 0;
    } else {
      uint _lockedStake = _lockedStakes[account];
      uint hoursSinceStaked = (block.timestamp - stakingStartedTime) % 3600;
      if (hoursSinceStaked < 7143) { // 7142 * 0.014 = 99.988 %
        // percentage unlocked = hours since staked * 0.014
        vp = (_lockedStake * hoursSinceStaked * 14) / 100000;
      } else {
        // hoursSinceStaked >= 7143 = 297.625 * 24
        // during day 298 voting power becomes 100% of the staked MDS
        vp = _lockedStake;
      }
    }
    vp += _unlockedStakes[account];
  }
}
