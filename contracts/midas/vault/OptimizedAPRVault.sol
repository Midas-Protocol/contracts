// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { IGenericLender } from "../../external/angle/IGenericLender.sol";
import { SafeOwnableUpgradeable } from "../SafeOwnableUpgradeable.sol";
import { MultiStrategyVault, AdapterConfig, VaultFees } from "./MultiStrategyVault.sol";
import { RewardsClaimer } from "../RewardsClaimer.sol";
import { MidasFlywheel } from "../strategies/flywheel/MidasFlywheel.sol";

import { SafeERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC20MetadataUpgradeable as IERC20Metadata } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { ERC20Upgradeable as IERC20 } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { FlywheelCore } from "flywheel/FlywheelCore.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

struct LendStatus {
  string name;
  uint256 assets;
  uint256 rate;
  address addr;
}

contract OptimizedAPRVault is MultiStrategyVault, RewardsClaimer {
  using SafeERC20Upgradeable for IERC20;

  uint64 internal constant _BPS = 1e18;

  bool public emergencyExit;

  uint256 public withdrawalThreshold;

  address public registry;

  mapping(IERC20 => MidasFlywheel) public flywheelForRewardToken;

  address public flywheelLogic;

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
    address registry_,
    IERC20[] memory rewardTokens_,
    address flywheelLogic_
  ) public initializer {
    __MultiStrategyVault_init(asset_, adapters_, adapterCount_, fees_, feeRecipient_, depositLimit_, owner_);
    __RewardsClaimer_init(address(this), rewardTokens_);
    registry = registry_;
    flywheelLogic = flywheelLogic_;
    for (uint256 i; i < rewardTokens_.length; ++i) {
      _deployFlywheelForRewardToken(rewardTokens_[i]);
    }
  }

  function addRewardToken(IERC20 token_) public onlyOwner {
    _deployFlywheelForRewardToken(token_);
    rewardTokens.push(token_);
  }

  function _deployFlywheelForRewardToken(IERC20 token_) internal {
    require(address(flywheelForRewardToken[token_]) == address(0), "already added");

    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(flywheelLogic, registry, "");
    MidasFlywheel newFlywheel = MidasFlywheel(address(proxy));

    newFlywheel.initialize(
      ERC20(address(token_)),
      IFlywheelRewards(address(this)),
      IFlywheelBooster(address(0)),
      address(this)
    );
    FuseFlywheelDynamicRewards rewardsContract = new FuseFlywheelDynamicRewards(
      FlywheelCore(address(newFlywheel)),
      1 days
    );
    newFlywheel.setFlywheelRewards(rewardsContract);
    token_.approve(address(rewardsContract), type(uint256).max);
    newFlywheel.updateFeeSettings(0, address(this));
    // TODO accept owner
    newFlywheel._setPendingOwner(owner());

    // lets the vault shareholders accrue
    newFlywheel.addStrategyForRewards(ERC20(address(this)));
    flywheelForRewardToken[token_] = newFlywheel;
  }

  function adaptersCount() public view returns (uint8) {
    return adapterCount;
  }

  /// @notice View function to check the current state of the strategy
  /// @return Returns the status of all lenders attached the strategy
  function lendStatuses() external view returns (LendStatus[] memory) {
    LendStatus[] memory statuses = new LendStatus[](adapterCount);
    for (uint256 i; i < adapterCount; ++i) {
      LendStatus memory s;
      s.name = adapters[i].adapter.lenderName();
      s.addr = address(adapters[i].adapter);
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

  /// @notice Returns the weighted apr of all adapters
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
  /// @param allocations List of allocations (in bps of the nav) that should be allocated to each adapter
  function estimatedAPR(uint64[] calldata allocations) public view returns (uint256, int256[] memory) {
    uint256 weightedAPRScaled = 0;
    int256[] memory adapterAdjustedAmounts = new int256[](adapterCount);
    if (adapterCount != allocations.length) revert IncorrectListLength();

    uint256 bal = estimatedTotalAssets();
    if (bal == 0) return (weightedAPRScaled, adapterAdjustedAmounts);

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
      adapterAdjustedAmounts[i] = adjustedAmount;
    }
    if (allocation != _BPS) revert InvalidAllocations();

    return (weightedAPRScaled / bal, adapterAdjustedAmounts);
  }

  // =============================== CORE FUNCTIONS ==============================

  /// @notice Harvests the Strategy, recognizing any profits or losses and adjusting
  /// the Strategy's position.
  function harvest(uint64[] calldata adapterAllocationsHint) external {
    // TODO emit event about the harvested returns and currently deposited assets
    _adjustPosition(adapterAllocationsHint);
  }

  function _adjustPosition(uint64[] calldata adapterAllocationsHint) internal {
    // do not redeposit if emergencyExit is activated
    if (emergencyExit) return;

    // We just keep all money in `asset` if we dont have any adapters
    if (adapterCount == 0) return;

    uint256 estimatedAprHint;
    int256[] memory adapterAdjustedAmounts;
    if (adapterAllocationsHint.length != 0)
      (estimatedAprHint, adapterAdjustedAmounts) = estimatedAPR(adapterAllocationsHint);

    uint256 currentAPR = estimatedAPR();
    if (currentAPR < estimatedAprHint) {
      // The hint was successful --> we find a better allocation than the current one

      // calculate the "delta" - the difference between
      // the requested amount to withdraw and the actually withdrawn amount
      uint256 deltaWithdraw;
      for (uint256 i; i < adapterCount; ++i) {
        if (adapterAdjustedAmounts[i] < 0) {
          deltaWithdraw +=
            uint256(-adapterAdjustedAmounts[i]) -
            adapters[i].adapter.withdraw(uint256(-adapterAdjustedAmounts[i]));
        }
      }
      // TODO deltaWithdraw is always 0 for compound markets deposits

      // If the strategy didn't succeed to withdraw the intended funds
      if (deltaWithdraw > withdrawalThreshold) revert IncorrectDistribution();

      for (uint256 i; i < adapterCount; ++i) {
        if (adapterAdjustedAmounts[i] > 0) {
          // As `deltaWithdraw` is less than `withdrawalThreshold` (a dust)
          // It is not a problem to compensate on an arbitrary adapter as it will only slightly impact global APR
          if (adapterAdjustedAmounts[i] > int256(deltaWithdraw)) {
            adapterAdjustedAmounts[i] -= int256(deltaWithdraw);
            deltaWithdraw = 0;
          } else {
            deltaWithdraw -= uint256(adapterAdjustedAmounts[i]);
          }
          // redeposit through the adapters
          adapters[i].adapter.deposit(uint256(adapterAdjustedAmounts[i]), address(this));
        }
        // record the applied allocation in storage
        adapters[i].allocation = adapterAllocationsHint[i];
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

  function beforeClaim() internal override {
    for (uint256 i; i < adapterCount; ++i) {
      adapters[i].adapter.claimRewards();
    }
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    super._afterTokenTransfer(from, to, amount);
    for (uint256 i; i < rewardTokens.length; ++i) {
      flywheelForRewardToken[rewardTokens[i]].accrue(ERC20(address(this)), from, to);
    }
  }

  function getAllFlywheels() external view returns (MidasFlywheel[] memory allFlywheels) {
    allFlywheels = new MidasFlywheel[](rewardTokens.length);
    for (uint256 i = 0; i < rewardTokens.length; i++) {
      allFlywheels[i] = flywheelForRewardToken[rewardTokens[i]];
    }
  }
}
