// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { VaultFees, IERC20 } from "./IVault.sol";
import "../strategies/CompoundMarketERC4626.sol";
import "../DiamondExtension.sol";
import { MidasFlywheel } from "../strategies/flywheel/MidasFlywheel.sol";
import { SafeOwnableUpgradeable, OwnableUpgradeable } from "../../midas/SafeOwnableUpgradeable.sol";

import { ERC4626Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import { MathUpgradeable as Math } from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";

struct AdapterConfig {
  CompoundMarketERC4626 adapter;
  uint64 allocation;
}

abstract contract MultiStrategyVaultStorage is
  SafeOwnableUpgradeable,
  ERC4626Upgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable
{

  uint256 internal constant SECONDS_PER_YEAR = 365.25 days;

  uint8 internal _decimals;
  string internal _name;
  string internal _symbol;

  bytes32 public contractName;

  uint256 public highWaterMark;
  uint256 public assetsCheckpoint;
  uint256 public feesUpdatedAt;

  VaultFees public fees;
  VaultFees public proposedFees;
  uint256 public proposedFeeTime;
  address public feeRecipient;

  AdapterConfig[10] public adapters;
  AdapterConfig[10] public proposedAdapters;
  uint8 public adapterCount;
  uint8 public proposedAdapterCount;
  uint256 public proposedAdapterTime;

  uint256 public quitPeriod;
  uint256 public depositLimit;

  //  EIP-2612 STORAGE
  uint256 internal INITIAL_CHAIN_ID;
  bytes32 internal INITIAL_DOMAIN_SEPARATOR;
  mapping(address => uint256) public nonces;

  // OptimizedAPRVault storage

  bool public emergencyExit;
  uint256 public withdrawalThreshold;
  address public registry;
  mapping(IERC20 => MidasFlywheel) public flywheelForRewardToken;
  address public flywheelLogic;

  /// @notice the address to send rewards
  address public rewardDestination;

  /// @notice the array of reward tokens to send to
  IERC20[] public rewardTokens;
}
