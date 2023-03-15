// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../external/angle/IGenericLender.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../SafeOwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

struct LendStatus {
  string name;
  uint256 assets;
  uint256 rate;
  address add;
}

contract OptimizerAPRStrategy is SafeOwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint64 internal constant _BPS = 10000;

  /// @notice See note on `setEmergencyExit()`
  bool public emergencyExit;

  IGenericLender[] public lenders;
  uint256 public withdrawalThreshold;

  /// @notice Reference to the ERC20 farmed by this strategy
  IERC20Upgradeable public want;

  event EmergencyExitActivated();

  error IncorrectListLength();
  error IncorrectDistribution();
  error InvalidShares();

  function initialize(IERC20Upgradeable _want) public initializer {
    want = _want;
  }

  // =============================== VIEW FUNCTIONS ==============================

  /// @notice View function to check the current state of the strategy
  /// @return Returns the status of all lenders attached the strategy
  function lendStatuses() external view returns (LendStatus[] memory) {
    uint256 lendersLength = lenders.length;
    LendStatus[] memory statuses = new LendStatus[](lendersLength);
    for (uint256 i; i < lendersLength; ++i) {
      LendStatus memory s;
      s.name = lenders[i].lenderName();
      s.add = address(lenders[i]);
      s.assets = lenders[i].nav();
      s.rate = lenders[i].apr();
      statuses[i] = s;
    }
    return statuses;
  }

  /// @notice View function to check the total assets lent
  function lentTotalAssets() public view returns (uint256) {
    uint256 nav;
    uint256 lendersLength = lenders.length;
    for (uint256 i; i < lendersLength; ++i) {
      nav += lenders[i].nav();
    }
    return nav;
  }

  /// @notice View function to check the total assets managed by the strategy
  function estimatedTotalAssets() public view returns (uint256 nav) {
    nav = lentTotalAssets() + want.balanceOf(address(this));
  }

  /// @notice View function to check the number of lending platforms
  function numLenders() external view returns (uint256) {
    return lenders.length;
  }

  /// @notice Returns the weighted apr of all lenders
  /// @dev It's computed by doing: `sum(nav * apr) / totalNav`
  function estimatedAPR() public view returns (uint256) {
    uint256 bal = estimatedTotalAssets();
    if (bal == 0) {
      return 0;
    }

    uint256 weightedAPR;
    uint256 lendersLength = lenders.length;
    for (uint256 i; i < lendersLength; ++i) {
      weightedAPR += lenders[i].weightedApr();
    }

    return weightedAPR / bal;
  }

  /// @notice Returns the weighted apr in an hypothetical world where the strategy splits its nav
  /// in respect to shares
  /// @param shares List of shares (in bps of the nav) that should be allocated to each lender
  function estimatedAPR(uint64[] memory shares)
    public
    view
    returns (uint256 weightedAPR, int256[] memory lenderAdjustedAmounts)
  {
    uint256 lenderLength = lenders.length;
    lenderAdjustedAmounts = new int256[](lenderLength);
    if (lenderLength != shares.length) revert IncorrectListLength();

    uint256 bal = estimatedTotalAssets();
    if (bal == 0) return (weightedAPR, lenderAdjustedAmounts);

    uint256 share;
    for (uint256 i; i < lenderLength; ++i) {
      share += shares[i];
      uint256 futureDeposit = (bal * shares[i]) / _BPS;
      // It won't overflow for `decimals <= 18`, as it would mean gigantic amounts
      int256 adjustedAmount = int256(futureDeposit) - int256(lenders[i].nav());
      lenderAdjustedAmounts[i] = adjustedAmount;
      weightedAPR += futureDeposit * lenders[i].aprAfterDeposit(adjustedAmount);
    }
    if (share != 10000) revert InvalidShares();

    weightedAPR /= bal;
  }

  // =============================== CORE FUNCTIONS ==============================

  /// @notice Harvests the Strategy, recognizing any profits or losses and adjusting
  /// the Strategy's position.
  function harvest(bytes memory data) external {
    _report();
    _adjustPosition(data);
  }

  function _report() internal {
    if (emergencyExit) {
      IGenericLender[] memory lendersList = lenders;
      uint256 lendersListLength = lendersList.length;
      for (uint256 i; i < lendersListLength; ++i) {
        lendersList[i].emergencyWithdrawAndPause();
      }
    } else {
      // TODO emit event about the harvested returns and currently deposited assets
      //_prepareReturn();
      //emit Harvested(profit, loss, debtPayment, debtOutstanding);
    }
  }

  function _adjustPosition(bytes memory data) internal {
    // Emergency exit is dealt with at beginning of harvest
    if (emergencyExit) return;

    // Storing the `lenders` array in a cache variable
    IGenericLender[] memory lendersList = lenders;
    uint256 lendersListLength = lendersList.length;
    // We just keep all money in `want` if we dont have any lenders
    if (lendersListLength == 0) return;

    uint64[] memory lenderSharesHint = abi.decode(data, (uint64[]));

    uint256 estimatedAprHint;
    int256[] memory lenderAdjustedAmounts;
    if (lenderSharesHint.length != 0) (estimatedAprHint, lenderAdjustedAmounts) = estimatedAPR(lenderSharesHint);

    // estimated APR might be
    uint256 currentAPR = estimatedAPR();
    // The hint was successful --> we find a better allocation than the current one
    if (currentAPR < estimatedAprHint) {
      uint256 deltaWithdraw;
      for (uint256 i; i < lendersListLength; ++i) {
        if (lenderAdjustedAmounts[i] < 0) {
          deltaWithdraw +=
            uint256(-lenderAdjustedAmounts[i]) -
            lendersList[i].withdraw(uint256(-lenderAdjustedAmounts[i]));
        }
      }

      // If the strategy didn't succeed to withdraw the intended funds -> revert and force the greedy path
      if (deltaWithdraw > withdrawalThreshold) revert IncorrectDistribution();

      for (uint256 i; i < lendersListLength; ++i) {
        // As `deltaWithdraw` is inferior to `withdrawalThreshold` (a dust)
        // It is not critical to compensate on an arbitrary lender as it will only slightly impact global APR
        if (lenderAdjustedAmounts[i] > int256(deltaWithdraw)) {
          lenderAdjustedAmounts[i] -= int256(deltaWithdraw);
          deltaWithdraw = 0;
          want.safeTransfer(address(lendersList[i]), uint256(lenderAdjustedAmounts[i]));
          lendersList[i].deposit();
        } else if (lenderAdjustedAmounts[i] > 0) deltaWithdraw -= uint256(lenderAdjustedAmounts[i]);
      }
    }
  }

  // ================================= GOVERNANCE ================================

  /// @notice Activates emergency exit. Once activated, the Strategy will exit its
  /// position upon the next harvest, depositing all funds into the Manager as
  /// quickly as is reasonable given on-chain conditions.
  /// @dev This may only be called by the `PoolManager`, because when calling this the `PoolManager` should at the same
  /// time update the debt ratio
  /// @dev This function can only be called once by the `PoolManager` contract
  /// @dev See `poolManager.setEmergencyExit()` and `harvest()` for further details.
  function setEmergencyExit() external onlyOwner {
    emergencyExit = true;
    emit EmergencyExitActivated();
  }
}
