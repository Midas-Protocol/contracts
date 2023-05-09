// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../IRedemptionStrategy.sol";
import { SafeOwnable } from "../../midas/SafeOwnable.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LiquidatorsRegistryStorage is SafeOwnable {
  mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => IRedemptionStrategy)) public redemptionStrategiesByTokens;
  mapping(string => IRedemptionStrategy) public redemptionStrategiesByName;
}
