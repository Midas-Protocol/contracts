// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import { SafeOwnableUpgradeable } from "../../../midas/SafeOwnableUpgradeable.sol";
import "./MidasFlywheelCore.sol";

contract MidasReplacingFlywheel is MidasFlywheelCore {
  MidasFlywheelCore public flywheelToReplace;
  mapping(address => bool) private rewardsTransferred;

  function initialize(
    ERC20 _rewardToken,
    IFlywheelRewards _flywheelRewards,
    IFlywheelBooster _flywheelBooster,
    address _owner,
    MidasFlywheelCore _flywheelToReplace
  ) public initializer {
    initialize(_rewardToken, _flywheelRewards, _flywheelBooster, _owner);
    flywheelToReplace = _flywheelToReplace;
  }

  function getRewardsAccrued(address user) public override returns (uint256) {
    uint256 newStateRewardsAccrued = rewardsAccrued[user];
    if (newStateRewardsAccrued == 0 && !rewardsTransferred[user]) {
      rewardsTransferred[user] = true;
      rewardsAccrued[user] = flywheelToReplace.rewardsAccrued(user);
    }
    return rewardsAccrued[user];
  }

  function getStrategyState(ERC20 strategy) public override returns (RewardsState memory) {
    RewardsState memory newStateStrategyState = strategyState[strategy];
    if (newStateStrategyState.index == 0) {
      strategyState[strategy] = flywheelToReplace.strategyState(strategy);
    }
    return strategyState[strategy];
  }

  function getUserIndex(ERC20 strategy, address user) public override returns (uint224) {
    uint224 newStateUserIndex = userIndex[strategy][user];
    if (newStateUserIndex == 0) {
      userIndex[strategy][user] = flywheelToReplace.userIndex(strategy, user);
    }
    return userIndex[strategy][user];
  }
}
