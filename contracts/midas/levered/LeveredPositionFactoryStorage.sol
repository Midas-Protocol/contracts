// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { SafeOwnable } from "../../midas/SafeOwnable.sol";
import { IFuseFeeDistributor } from "../../compound/IFuseFeeDistributor.sol";
import { ILiquidatorsRegistry } from "../../liquidators/registry/ILiquidatorsRegistry.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LeveredPositionFactoryStorage is SafeOwnable {
  EnumerableSet.AddressSet internal accountsWithOpenPositions;
  mapping(address => EnumerableSet.AddressSet) internal positionsByAccount;
  EnumerableSet.AddressSet internal collateralMarkets;
  mapping(ICErc20 => EnumerableSet.AddressSet) internal borrowableMarketsByCollateral;

  mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => uint256)) public conversionSlippage;

  IFuseFeeDistributor public fuseFeeDistributor;
  ILiquidatorsRegistry public liquidatorsRegistry;
  uint256 public blocksPerYear;
}
