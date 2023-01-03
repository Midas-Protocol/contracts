// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { BaseFlywheelRewards } from "flywheel-v2/rewards/BaseFlywheelRewards.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { SafeTransferLib, ERC20 } from "solmate/utils/SafeTransferLib.sol";

contract ReplacingFlywheelDynamicRewards is FlywheelDynamicRewards {
  using SafeTransferLib for ERC20;

  FlywheelCore public replacedFlywheel;

  constructor(
    FlywheelCore _replacedFlywheel,
    FlywheelCore _flywheel,
    uint32 _cycleLength
  ) FlywheelDynamicRewards(_flywheel, _cycleLength) {
    ERC20 _rewardToken = _flywheel.rewardToken();
    _rewardToken.safeApprove(address(_replacedFlywheel), type(uint256).max);
  }

  function getNextCycleRewards(ERC20 strategy)
  internal
  override
  returns (uint192)
  {
    if (msg.sender == address(replacedFlywheel)) {
      return 0;
    } else {
      uint256 rewardAmount = rewardToken.balanceOf(address(strategy));
      if (rewardAmount != 0) {
        rewardToken.safeTransferFrom(
          address(strategy),
          address(this),
          rewardAmount
        );
      }
      return uint192(rewardAmount);
    }
  }
}
