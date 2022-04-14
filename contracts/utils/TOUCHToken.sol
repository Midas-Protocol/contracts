pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "../gauges/VeMDSToken.sol";

contract TOUCHToken is ERC20, Initializable {
  mapping(address => uint256) public stakingStartedTime;
  mapping(address => uint256) internal releasingStakes;
  mapping(address => uint256) internal accumulatedStakes;
  uint256 public totalStaked;
  VeMDSToken veToken;

  // TODO solmate ERC20 and initializable?
  constructor() ERC20("Midas TOUCH Token", "TOUCH", 18) {}

  function initialize(uint256 _initialSupply, VeMDSToken _veToken) initializer public {
    _mint(msg.sender, _initialSupply);
//    __ERC20_init("MyToken", "MTK");
    veToken = _veToken;
  }

// needs to be called from time to time
  function claimAccumulatedVotingPower() external returns (uint256) {
    return _claimAccumulatedVotingPower();
  }

  // needs to be called from time to time?
  function _claimAccumulatedVotingPower() internal returns (uint256) {
    uint256 accumulatedVotingPower = accumulatedVotingPowerOf(msg.sender);

    // mint the accumulated veTokens
    uint256 currentBalanceOfVeTokens = veToken.balanceOf(msg.sender);
    uint256 amountToMint = accumulatedVotingPower - currentBalanceOfVeTokens;
    if (amountToMint != 0) {
      veToken.mint(msg.sender, amountToMint);
    } else {
      uint256 totalStake = accumulatedStakes[msg.sender] + releasingStakes[msg.sender];
      if (accumulatedVotingPower == totalStake) {
        accumulatedStakes[msg.sender] = totalStake;
        stakingStartedTime[msg.sender] = 0;
        releasingStakes[msg.sender] = 0;
      }
    }

    return amountToMint;
  }

  function stake(uint256 amountToStake) public {
    require(amountToStake > 0, "amount to stake should be non-zero");
    _claimAccumulatedVotingPower();

    // call first, then change the state
    // safe methods not needed?
    transfer(address(this), amountToStake);

    // update releasing/accumulated state
    uint256 accumulatedVotingPower = accumulatedVotingPowerOf(msg.sender);
    releasingStakes[msg.sender] = accumulatedStakes[msg.sender] + releasingStakes[msg.sender] - accumulatedVotingPower;
    accumulatedStakes[msg.sender] = accumulatedVotingPower;

    releasingStakes[msg.sender] += amountToStake;
    totalStaked += amountToStake;
    stakingStartedTime[msg.sender] = block.timestamp;

    // emit stakinng event
  }

  // TODO unstaking period
  function unstake(uint256 amountToUnstake) public {
    uint256 totalStakePreUnstake = accumulatedStakes[msg.sender] + releasingStakes[msg.sender];
    require(amountToUnstake <= totalStakePreUnstake, "stake not enough");
    _claimAccumulatedVotingPower();

    releasingStakes[msg.sender] = totalStakePreUnstake - amountToUnstake;
    accumulatedStakes[msg.sender] = 0;
    totalStaked -= amountToUnstake;
    // reset if accumulating stake is left
    stakingStartedTime[msg.sender] = releasingStakes[msg.sender] != 0 ? block.timestamp : 0;

    // remove voting power from escrow
    veToken.burn(msg.sender, veToken.balanceOf(msg.sender));

    // call transfer in the end, as the reentrancy protection pattern requires
    ERC20(address(this)).transfer(msg.sender, amountToUnstake);

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
