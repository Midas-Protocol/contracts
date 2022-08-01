// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { SafeCastLib } from "solmate/utils/SafeCastLib.sol";

import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import "flywheel/FlywheelCore.sol";

/**
  @notice FlywheelCore with a performanceFee on all accumulated rewardsToken
 */
contract MidasFlywheelCore is FlywheelCore {
  using SafeTransferLib for ERC20;
  using SafeCastLib for uint256;

  /// @notice How much rewardsToken will be send to treasury
  uint256 performanceFee = 5e16; // 5%

  /// @notice Address that gets rewardsToken accrued by performanceFee
  address public feeRecipient; // TODO whats the default address?

  event UpdatedFeeSettings(
    uint256 oldPerformanceFee,
    uint256 newPerformanceFee,
    address oldFeeRecipient,
    address newFeeRecipient
  );

  constructor(
    ERC20 _rewardToken,
    IFlywheelRewards _flywheelRewards,
    IFlywheelBooster _flywheelBooster,
    address _owner,
    Authority _authority
  ) FlywheelCore(_rewardToken, _flywheelRewards, _flywheelBooster, _owner, _authority) {}

  /*///////////////////////////////////////////////////////////////
                        ACCRUE/CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @notice accumulate global rewards on a strategy
  function accrueStrategy(ERC20 strategy, RewardsState memory state)
    private
    override
    returns (RewardsState memory rewardsState)
  {
    // calculate accrued rewards through module
    uint256 strategyRewardsAccrued = flywheelRewards.getAccruedRewards(strategy, state.lastUpdatedTimestamp);

    rewardsState = state;
    if (strategyRewardsAccrued > 0) {
      // use the booster or token supply to calculate reward index denominator
      uint256 supplyTokens = address(flywheelBooster) != address(0)
        ? flywheelBooster.boostedTotalSupply(strategy)
        : strategy.totalSupply();

      uint224 deltaIndex;

      if (supplyTokens != 0) deltaIndex = ((strategyRewardsAccrued * ONE) / supplyTokens).safeCastTo224();

      uint256 accruedFees = (deltaIndex * performanceFee) / 1e18;

      rewardsAccrued[feeRecipient] += accruedFees;

      // accumulate rewards per token onto the index, multiplied by fixed-point factor
      rewardsState = RewardsState({
        index: state.index + (deltaIndex - accruedFees.safeCastTo224()),
        lastUpdatedTimestamp: block.timestamp.safeCastTo32()
      });
      strategyState[strategy] = rewardsState;
    }
  }

  /**
   * @notice Update performanceFee and/or feeRecipient
   * @dev Claim rewards first from the previous feeRecipient before changing it
   */
  function updateFeeSettings(uint256 _performanceFee, address _feeRecipient) external requiresAuth {
    emit UpdatedFeeSettings(performanceFee, _performanceFee, feeRecipient, _feeRecipient);

    performanceFee = _performanceFee;
    feeRecipient = _feeRecipient;
  }
}
