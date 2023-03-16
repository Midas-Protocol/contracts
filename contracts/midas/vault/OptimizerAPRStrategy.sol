// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../external/angle/IGenericLender.sol";
import { IERC20Upgradeable as IERC20 } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../SafeOwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./MultiStrategyVault.sol";

struct LendStatus {
  string name;
  uint256 assets;
  uint256 rate;
  address add;
}

contract OptimizerAPRStrategy is MultiStrategyVault {
  using SafeERC20Upgradeable for IERC20;

  uint64 internal constant _BPS = 1e18;

  /// @notice See note on `setEmergencyExit()`
  bool public emergencyExit;

  uint256 public withdrawalThreshold;

  event EmergencyExitActivated();

  error IncorrectListLength();
  error IncorrectDistribution();
  error InvalidShares();

  function initialize(
    IERC20 asset_,
    AdapterConfig[10] calldata adapters_,
    uint8 adapterCount_,
    VaultFees calldata fees_,
    address feeRecipient_,
    uint256 depositLimit_
  ) public override initializer {
    __MultiStrategyVault_init(asset_, adapters_, adapterCount_, fees_, feeRecipient_, depositLimit_);
  }

  // =============================== VIEW FUNCTIONS ==============================

  /// @notice View function to check the current state of the strategy
  /// @return Returns the status of all lenders attached the strategy
  function lendStatuses() external view returns (LendStatus[] memory) {
    LendStatus[] memory statuses = new LendStatus[](adapterCount);
    for (uint256 i; i < adapterCount; ++i) {
      LendStatus memory s;
      s.name = adapters[i].adapter.lenderName();
      s.add = address(adapters[i].adapter);
      s.assets = adapters[i].adapter.nav();
      s.rate = adapters[i].adapter.apr();
      statuses[i] = s;
    }
    return statuses;
  }

  /// @notice View function to check the total assets lent
  function lentTotalAssets() public view returns (uint256) {
    uint256 nav;
    for (uint256 i; i < adapterCount; ++i) {
      nav += adapters[i].adapter.nav();
    }
    return nav;
  }

  /// @notice View function to check the total assets managed by the strategy
  function estimatedTotalAssets() public view returns (uint256 nav) {
    nav = lentTotalAssets() + IERC20(asset()).balanceOf(address(this));
  }

  /// @notice View function to check the number of lending platforms
  function numLenders() external view returns (uint256) {
    return adapterCount;
  }

  /// @notice Returns the weighted apr of all lenders
  /// @dev It's computed by doing: `sum(nav * apr) / totalNav`
  function estimatedAPR() public view returns (uint256) {
    uint256 bal = estimatedTotalAssets();
    if (bal == 0) {
      return 0;
    }

    uint256 weightedAPR;
    for (uint256 i; i < adapterCount; ++i) {
      weightedAPR += adapters[i].adapter.weightedApr();
    }

    uint8 decimals = IERC20Metadata(asset()).decimals();
    return (weightedAPR * (10 ** decimals)) / bal;
  }

  /// @notice Returns the weighted apr in an hypothetical world where the strategy splits its nav
  /// in respect to shares
  /// @param shares List of shares (in bps of the nav) that should be allocated to each lender
  function estimatedAPR(uint64[] calldata shares)
    public
    view
    returns (uint256, int256[] memory)
  {
    uint256 weightedAPRScaled = 0;
    int256[] memory lenderAdjustedAmounts = new int256[](adapterCount);
    if (adapterCount != shares.length) revert IncorrectListLength();

    uint256 bal = estimatedTotalAssets();
    if (bal == 0) return (weightedAPRScaled, lenderAdjustedAmounts);

    uint256 share;
    for (uint256 i; i < adapterCount; ++i) {
      share += shares[i];
      uint256 futureDeposit = (bal * shares[i]) / _BPS;

      int256 adjustedAmount = int256(futureDeposit) - int256(adapters[i].adapter.nav());
      if (adjustedAmount > 0) {
        weightedAPRScaled += futureDeposit * adapters[i].adapter.aprAfterDeposit(uint256(adjustedAmount));
      } else {
        weightedAPRScaled += futureDeposit * adapters[i].adapter.aprAfterWithdraw(uint256(-adjustedAmount));
      }
      lenderAdjustedAmounts[i] = adjustedAmount;
    }
    if (share != _BPS) revert InvalidShares();

    return (weightedAPRScaled / bal, lenderAdjustedAmounts);
  }

  // =============================== CORE FUNCTIONS ==============================

  /// @notice Harvests the Strategy, recognizing any profits or losses and adjusting
  /// the Strategy's position.
  function harvest(uint64[] calldata shares) external {
    _report();
    _adjustPosition(shares);
  }

  function _report() internal {
    if (emergencyExit) {
      for (uint256 i; i < adapterCount; ++i) {
        adapters[i].adapter.emergencyWithdrawAndPause();
      }
    } else {
      // TODO emit event about the harvested returns and currently deposited assets
      //_prepareReturn();
      //emit Harvested(profit, loss, debtPayment, debtOutstanding);
    }
  }

  function _adjustPosition(uint64[] calldata lenderSharesHint) internal {
    // Emergency exit is dealt with at beginning of harvest
    if (emergencyExit) return;

    // We just keep all money in `asset` if we dont have any lenders
    if (adapterCount == 0) return;

    uint256 estimatedAprHint;
    int256[] memory lenderAdjustedAmounts;
    if (lenderSharesHint.length != 0) (estimatedAprHint, lenderAdjustedAmounts) = estimatedAPR(lenderSharesHint);

    // estimated APR might be
    uint256 currentAPR = estimatedAPR();
    // The hint was successful --> we find a better allocation than the current one
    if (currentAPR < estimatedAprHint) {
      uint256 deltaWithdraw;
      for (uint256 i; i < adapterCount; ++i) {
        if (lenderAdjustedAmounts[i] < 0) {
          deltaWithdraw +=
            uint256(-lenderAdjustedAmounts[i]) -
            adapters[i].adapter.withdraw(uint256(-lenderAdjustedAmounts[i]));
        }
      }
      // TODO deltaWithdraw is always 0 for compound markets deposits

      // If the strategy didn't succeed to withdraw the intended funds -> revert and force the greedy path
      if (deltaWithdraw > withdrawalThreshold) revert IncorrectDistribution();

      for (uint256 i; i < adapterCount; ++i) {
        // As `deltaWithdraw` is less than `withdrawalThreshold` (a dust)
        // It is not critical to compensate on an arbitrary lender as it will only slightly impact global APR
        if (lenderAdjustedAmounts[i] > int256(deltaWithdraw)) {
          lenderAdjustedAmounts[i] -= int256(deltaWithdraw);
          deltaWithdraw = 0;
          IERC20(asset()).approve(address(adapters[i].adapter), uint256(lenderAdjustedAmounts[i]));
          adapters[i].adapter.deposit(uint256(lenderAdjustedAmounts[i]), address(this));
        } else if (lenderAdjustedAmounts[i] > 0) {
          deltaWithdraw -= uint256(lenderAdjustedAmounts[i]);
        }
        adapters[i].allocation = lenderSharesHint[i];
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
