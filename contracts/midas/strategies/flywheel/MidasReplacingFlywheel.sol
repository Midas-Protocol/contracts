// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "./MidasFlywheel.sol";

import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";

contract MidasReplacingFlywheel is MidasFlywheel {
  MidasFlywheelCore public flywheelToReplace;
  mapping(address => bool) private rewardsTransferred;

  function reinitialize(MidasFlywheelCore _flywheelToReplace) public onlyOwnerOrAdmin {
    flywheelToReplace = _flywheelToReplace;
  }

  function rewardsAccrued(address user) public override returns (uint256) {
    if (address(flywheelToReplace) != address(0)) {
      uint256 newStateRewardsAccrued = _rewardsAccrued[user];
      if (newStateRewardsAccrued == 0 && !rewardsTransferred[user]) {
        rewardsTransferred[user] = true;
        _rewardsAccrued[user] = flywheelToReplace.rewardsAccrued(user);
      }
    }
    return _rewardsAccrued[user];
  }

  function strategyState(ERC20 strategy) public override returns (uint224, uint32) {
    if (address(flywheelToReplace) != address(0)) {
      RewardsState memory newStateStrategyState = _strategyState[strategy];
      if (newStateStrategyState.index == 0) {
        (uint224 index, uint32 ts) = flywheelToReplace.strategyState(strategy);
        _strategyState[strategy] = RewardsState(index, ts);
      }
    }
    return (_strategyState[strategy].index, _strategyState[strategy].lastUpdatedTimestamp);
  }

  function userIndex(ERC20 strategy, address user) public override returns (uint224) {
    if (address(flywheelToReplace) != address(0)) {
      uint224 newStateUserIndex = _userIndex[strategy][user];
      if (newStateUserIndex == 0) {
        _userIndex[strategy][user] = flywheelToReplace.userIndex(strategy, user);
      }
    }
    return _userIndex[strategy][user];
  }

  function addInitializedStrategy(ERC20 strategy) public onlyOwner {
    (uint224 index, ) = strategyState(strategy);
    if (index > 0) {
      ERC20[] memory strategies = this.getAllStrategies();
      for (uint8 i = 0; i < strategies.length; i++) {
        require(address(strategy) != address(strategies[i]), "!added");
      }

      allStrategies.push(strategy);
      emit AddStrategy(address(strategy));
    }
  }
}
