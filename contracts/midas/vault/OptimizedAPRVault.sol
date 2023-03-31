// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { IGenericLender } from "../../external/angle/IGenericLender.sol";
import { IERC20Upgradeable as IERC20, IERC20MetadataUpgradeable as IERC20Metadata } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { SafeOwnableUpgradeable } from "../SafeOwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { MultiStrategyVault, AdapterConfig, VaultFees } from "./MultiStrategyVault.sol";

struct LendStatus {
  string name;
  uint256 assets;
  uint256 rate;
  address add;
}

contract OptimizedAPRVault is MultiStrategyVault {
  using SafeERC20Upgradeable for IERC20;

  uint64 internal constant _BPS = 1e18;

  bool public emergencyExit;

  uint256 public withdrawalThreshold;

  address public registry;

  event EmergencyExitActivated();
  event Harvested(uint256 totalAssets, uint256 aprBefore, uint256 aprAfter);

  error IncorrectListLength();
  error IncorrectDistribution();

  function initializeWithRegistry(
    IERC20 asset_,
    AdapterConfig[10] calldata adapters_,
    uint8 adapterCount_,
    VaultFees calldata fees_,
    address feeRecipient_,
    uint256 depositLimit_,
    address owner_,
    address registry_
  ) public initializer {
    __MultiStrategyVault_init(asset_, adapters_, adapterCount_, fees_, feeRecipient_, depositLimit_, owner_);
    registry = registry_;
  }

  function reinitialize(address registry_) public reinitializer(2) {
    registry = registry_;
  }

  /// @notice View function to check the current state of the strategy
  /// @return Returns the status of all lenders attached the strategy
  function lendStatuses() external view returns (LendStatus[] memory) {
    LendStatus[] memory statuses = new LendStatus[](adapterCount);
    for (uint256 i; i < adapterCount; ++i) {
      LendStatus memory s;
      s.name = adapters[i].adapter.lenderName();
      s.add = address(adapters[i].adapter);
      s.assets = adapters[i].adapter.balanceOfUnderlying(address(this));
      s.rate = adapters[i].adapter.apr();
      statuses[i] = s;
    }
    return statuses;
  }

  /// @notice View function to check the total assets lent
  function lentTotalAssets() public view returns (uint256) {
    uint256 nav;
    for (uint256 i; i < adapterCount; ++i) {
      nav += adapters[i].adapter.balanceOfUnderlying(address(this));
    }
    return nav;
  }

  /// @notice View function to check the total assets managed by the strategy
  function estimatedTotalAssets() public view returns (uint256 nav) {
    nav = lentTotalAssets() + IERC20(asset()).balanceOf(address(this));
  }

  /// @notice view function to check the hypothetical APY after the deposit of some amount
  function supplyAPY(uint256 amount) public view returns (uint256) {
    uint256 bal = estimatedTotalAssets();
    if (bal == 0 && amount == 0) {
      return 0;
    }

    uint256 weightedAPR;
    for (uint256 i; i < adapterCount; ++i) {
      weightedAPR += adapters[i].adapter.weightedAprAfterDeposit(amount);
    }

    uint8 decimals = IERC20Metadata(asset()).decimals();
    return (weightedAPR * (10**decimals)) / (bal + amount);
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
    return (weightedAPR * (10**decimals)) / bal;
  }

  /// @notice Returns the weighted apr in an hypothetical world where the strategy splits its nav
  /// in respect to allocations
  /// @param allocations List of allocations (in bps of the nav) that should be allocated to each lender
  function estimatedAPR(uint64[] calldata allocations) public view returns (uint256, int256[] memory) {
    uint256 weightedAPRScaled = 0;
    int256[] memory lenderAdjustedAmounts = new int256[](adapterCount);
    if (adapterCount != allocations.length) revert IncorrectListLength();

    uint256 bal = estimatedTotalAssets();
    if (bal == 0) return (weightedAPRScaled, lenderAdjustedAmounts);

    uint256 allocation;
    for (uint256 i; i < adapterCount; ++i) {
      allocation += allocations[i];
      uint256 futureDeposit = (bal * allocations[i]) / _BPS;

      int256 adjustedAmount = int256(futureDeposit) - int256(adapters[i].adapter.balanceOfUnderlying(address(this)));
      if (adjustedAmount > 0) {
        weightedAPRScaled += futureDeposit * adapters[i].adapter.aprAfterDeposit(uint256(adjustedAmount));
      } else {
        weightedAPRScaled += futureDeposit * adapters[i].adapter.aprAfterWithdraw(uint256(-adjustedAmount));
      }
      lenderAdjustedAmounts[i] = adjustedAmount;
    }
    if (allocation != _BPS) revert InvalidAllocations();

    return (weightedAPRScaled / bal, lenderAdjustedAmounts);
  }

  // =============================== CORE FUNCTIONS ==============================

  /// @notice Harvests the Strategy, recognizing any profits or losses and adjusting
  /// the Strategy's position.
  function harvest(uint64[] calldata lenderAllocationsHint) external {
    // TODO emit event about the harvested returns and currently deposited assets
    _adjustPosition(lenderAllocationsHint);
  }

  function _adjustPosition(uint64[] calldata lenderAllocationsHint) internal {
    // do not redeposit if emergencyExit is activated
    if (emergencyExit) return;

    // We just keep all money in `asset` if we dont have any lenders
    if (adapterCount == 0) return;

    uint256 estimatedAprHint;
    int256[] memory lenderAdjustedAmounts;
    if (lenderAllocationsHint.length != 0)
      (estimatedAprHint, lenderAdjustedAmounts) = estimatedAPR(lenderAllocationsHint);

    uint256 currentAPR = estimatedAPR();
    if (currentAPR < estimatedAprHint) {
      // The hint was successful --> we find a better allocation than the current one

      // calculate the "delta" - the difference between
      // the requested amount to withdraw and the actually withdrawn amount
      uint256 deltaWithdraw;
      for (uint256 i; i < adapterCount; ++i) {
        if (lenderAdjustedAmounts[i] < 0) {
          deltaWithdraw +=
            uint256(-lenderAdjustedAmounts[i]) -
            adapters[i].adapter.withdraw(uint256(-lenderAdjustedAmounts[i]));
        }
      }
      // TODO deltaWithdraw is always 0 for compound markets deposits

      // If the strategy didn't succeed to withdraw the intended funds
      if (deltaWithdraw > withdrawalThreshold) revert IncorrectDistribution();

      for (uint256 i; i < adapterCount; ++i) {
        if (lenderAdjustedAmounts[i] > 0) {
          // As `deltaWithdraw` is less than `withdrawalThreshold` (a dust)
          // It is not a problem to compensate on an arbitrary lender as it will only slightly impact global APR
          if (lenderAdjustedAmounts[i] > int256(deltaWithdraw)) {
            lenderAdjustedAmounts[i] -= int256(deltaWithdraw);
            deltaWithdraw = 0;
          } else {
            deltaWithdraw -= uint256(lenderAdjustedAmounts[i]);
          }
          // redeposit through the lenders adapters
          adapters[i].adapter.deposit(uint256(lenderAdjustedAmounts[i]), address(this));
        }
        // record the applied allocation in storage
        adapters[i].allocation = lenderAllocationsHint[i];
      }
    }

    emit Harvested(totalAssets(), currentAPR, estimatedAprHint);
  }

  function setEmergencyExit() external {
    require(msg.sender == owner() || msg.sender == registry, "not registry or owner");

    for (uint256 i; i < adapterCount; ++i) {
      adapters[i].adapter.withdrawAll();
    }

    emergencyExit = true;
    _pause();

    emit EmergencyExitActivated();
  }
}
