// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "fuse-flywheel/FuseFlywheelCore.sol";

contract MidasFuseFlywheelCore is FuseFlywheelCore {
  constructor(
    ERC20 _rewardToken,
    IFlywheelRewards _flywheelRewards,
    IFlywheelBooster _flywheelBooster,
    address _owner,
    Authority _authority
  ) FuseFlywheelCore(_rewardToken, _flywheelRewards, _flywheelBooster, _owner, _authority) {}
}
