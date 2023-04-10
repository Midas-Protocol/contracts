// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { OptimizedAPRVaultStorage } from "./OptimizedAPRVaultStorage.sol";
import { DiamondExtension } from "../DiamondExtension.sol";

import { ERC4626Upgradeable, ContextUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

abstract contract OptimizedAPRVaultExtension is
  OptimizedAPRVaultStorage,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable,
  ERC4626Upgradeable,
  DiamondExtension
{
  function _msgSender() internal view override(ContextUpgradeable, Context) returns (address) {
    return msg.sender;
  }

  function _msgData() internal view override(ContextUpgradeable, Context) returns (bytes calldata) {
    return msg.data;
  }
}
