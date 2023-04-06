// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { OptimizedAPRVaultStorage, VaultFees, AdapterConfig } from "./OptimizedAPRVaultStorage.sol";
import { DiamondExtension } from "../DiamondExtension.sol";

import { ERC4626Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import { MathUpgradeable as Math } from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";
import { IERC20MetadataUpgradeable as IERC20Metadata } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

abstract contract OptimizedAPRVaultExtension is
  OptimizedAPRVaultStorage,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable,
  ERC4626Upgradeable,
  DiamondExtension
{
  error NotPassedQuitPeriod();
  error AssetInvalid();
  error InvalidConfig();
  error InvalidVaultFees();
  error InvalidFeeRecipient();

  function _verifyAdapterConfig(AdapterConfig[10] calldata newAdapters, uint8 adapterCount_) internal view {
    if (adapterCount_ == 0 || adapterCount_ > 10) revert InvalidConfig();

    uint256 totalAllocation;
    for (uint8 i; i < adapterCount_; i++) {
      if (newAdapters[i].adapter.asset() != asset()) revert AssetInvalid();

      uint256 allocation = uint256(newAdapters[i].allocation);
      if (allocation == 0) revert InvalidConfig();

      totalAllocation += allocation;
    }
    if (totalAllocation != 1e18) revert InvalidConfig();
  }

  function initialize(IERC20Metadata asset_) internal {
    __SafeOwnable_init(msg.sender);
    __ERC4626_init(asset_);
  }
}
