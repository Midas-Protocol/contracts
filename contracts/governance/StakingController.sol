// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "./VeMDSToken.sol";

// TODO upgradeable?
contract StakingController is Initializable {
  mapping(address => uint256) public stakingStartedTime;
  mapping(address => uint256) internal releasingStakes;
  mapping(address => uint256) internal accumulatedStakes;
  uint256 public totalStaked;
  mapping(address => uint256) public unstakeDeclaredTime;
  mapping(address => uint256) public unstakeDeclaredAmount;
  VeMDSToken veToken;
  TOUCHToken touchToken;

  error UnstakeTooEarly();
  error UnstakeNotDeclared();
  error UnstakeAlreadyDeclared();
  error UnstakeAmountZero();
  error StakeAmountZero();
  error StakeNotEnough();

  function initialize(VeMDSToken _veToken, TOUCHToken _touchToken) initializer public {
    veToken = _veToken;
    touchToken = _touchToken;
  }

  // needs to be called from time to time
  function claimAccumulatedVotingPower() external returns (uint256) {
    return _claimAccumulatedVotingPower(msg.sender);
  }

  function _claimAccumulatedVotingPower(address account) internal returns (uint256) {
    uint256 accumulatedVotingPower = accumulatedVotingPowerOf(account);

    // mint the accumulated veTokens
    uint256 currentBalanceOfVeTokens = veToken.balanceOf(account);
    uint256 amountToMint = accumulatedVotingPower - currentBalanceOfVeTokens;
    if (amountToMint != 0) {
      veToken.mint(account, amountToMint);
    } else {
      uint256 totalStake = accumulatedStakes[account] + releasingStakes[account];
      if (accumulatedVotingPower == totalStake) {
        accumulatedStakes[account] = totalStake;
        stakingStartedTime[account] = 0;
        releasingStakes[account] = 0;
      }
    }

    return amountToMint;
  }

  function stake(uint256 amountToStake) public {
    if (amountToStake == 0) revert StakeAmountZero();

    _claimAccumulatedVotingPower(msg.sender);

    // call first, then change the state
    // safe methods not needed?
    touchToken.transferFrom(msg.sender, address(this), amountToStake);

    // update releasing/accumulated state
    uint256 accumulatedVotingPower = accumulatedVotingPowerOf(msg.sender);
    releasingStakes[msg.sender] = accumulatedStakes[msg.sender] + releasingStakes[msg.sender] - accumulatedVotingPower;
    accumulatedStakes[msg.sender] = accumulatedVotingPower;

    releasingStakes[msg.sender] += amountToStake;
    totalStaked += amountToStake;
    stakingStartedTime[msg.sender] = block.timestamp;

    // emit stakinng event
  }

  // unstake has to be declared 7 days prior to the unstaking
  function declareUnstake(uint256 amountToUnstake) public {
    if (amountToUnstake == 0) revert UnstakeAmountZero();
    if (unstakeDeclaredTime[msg.sender] != 0) revert UnstakeAlreadyDeclared();

    unstakeDeclaredTime[msg.sender] = block.timestamp;
    unstakeDeclaredAmount[msg.sender] = amountToUnstake;

    // emit unstake declared event
  }

  // unstaking can be done
  // - by the owner 7 days after declaring it or
  // - by anyone 10 days after declaring it
  function unstake(address account) public {
    if (unstakeDeclaredTime[account] == 0) revert UnstakeNotDeclared();
    if (unstakeDeclaredTime[account] > block.timestamp - 7 days) revert UnstakeTooEarly();

    // not possible because of earlier UnstakeNotDeclared thrown
//    if (unstakeDeclaredAmount[account] == 0) revert UnstakeAmountZero();


    if (msg.sender != account && unstakeDeclaredTime[account] > block.timestamp - 10 days) revert UnstakeTooEarly();

    uint256 amountToUnstake = unstakeDeclaredAmount[account];

    uint256 totalStakePreUnstake = accumulatedStakes[account] + releasingStakes[account];
    if (amountToUnstake > totalStakePreUnstake) revert StakeNotEnough();

    // not needed
    //    _claimAccumulatedVotingPower(account);

    releasingStakes[account] = totalStakePreUnstake - amountToUnstake;
    accumulatedStakes[account] = 0;
    totalStaked -= amountToUnstake;
    // reset if accumulating stake is left
    stakingStartedTime[account] = releasingStakes[account] != 0 ? block.timestamp : 0;

    // remove voting power from escrow
    veToken.burn(account, veToken.balanceOf(account));

    //
    unstakeDeclaredTime[account] = 0;
    unstakeDeclaredAmount[account] = 0;

    // call transfer in the end, as the reentrancy protection pattern requires
    touchToken.transfer(account, amountToUnstake);

    // emit unstaking event
  }

  function stakeOf(address account) public view returns (uint256) {
    return releasingStakes[account] + accumulatedStakes[account];
  }

  function accumulatedVotingPowerOf(address account) public view returns (uint256 vp) {
    uint256 stakingStarted = stakingStartedTime[account];
    if (stakingStarted == 0) {
      return 0;
    } else {
      uint256 releasingStake = releasingStakes[account];
      uint256 hoursSinceStaked = (block.timestamp - stakingStarted) / 3600;
      if (hoursSinceStaked < 7143) { // 7142 * 0.014 = 99.988 %
        // percentage released = hours since staked * 0.014
        vp = (releasingStake * hoursSinceStaked * 14) / 100_000;
      } else {
        // hoursSinceStaked >= 7143 = 297.625 * 24
        // during day 298 voting power becomes 100% of the staked MDS
        vp = releasingStake;
      }
    }
    vp += accumulatedStakes[account];
  }
}
