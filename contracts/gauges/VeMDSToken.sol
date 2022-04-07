// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "flywheel-v2/token/ERC20Gauges.sol";

import "./GaugesController.sol";

// TODO integrate with FlywheelGaugeRewards
// TODO research ERC20VotesUpgradeable
contract VeMDSToken is Initializable, ERC20Gauges {
  mapping(address => uint256) public stakingStartedTime;
  mapping(address => uint256) public stakes;
  IERC20Upgradeable public mdsToken;

  constructor(
    uint32 _gaugeCycleLength,
    uint32 _incrementFreezeWindow,
    address _owner,
    Authority _authority
)
  ERC20Gauges(_gaugeCycleLength, _incrementFreezeWindow)
  Auth(_owner, _authority)
  ERC20("voting escrow MDS", "veMDS", 18)
  {

  }

  function initialize(address _mdsTokenAddress) public initializer {
    mdsToken = IERC20Upgradeable(_mdsTokenAddress); // TODO typed contract param
  }

  // TODO move in gov token
  function stake(uint256 amount) public {
    transferFrom(msg.sender, address(this), amount);
    stakingStartedTime[msg.sender] = block.timestamp;
    stakes[msg.sender] = amount;
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
