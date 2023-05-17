// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../IRedemptionStrategy.sol";
import { SafeOwnable } from "../../midas/SafeOwnable.sol";
import { AddressesProvider } from "../../midas/AddressesProvider.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LiquidatorsRegistryStorage is SafeOwnable {
  AddressesProvider public ap;

  EnumerableSet.AddressSet internal redemptionStrategies;
  mapping(string => IRedemptionStrategy) public redemptionStrategiesByName;
  mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => IRedemptionStrategy)) public redemptionStrategiesByTokens;
}
