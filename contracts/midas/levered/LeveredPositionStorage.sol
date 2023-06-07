// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { ILeveredPositionFactory } from "./ILeveredPositionFactory.sol";
import { IComptroller } from "../../compound/ComptrollerInterface.sol";
import { ICErc20 } from "../../compound/CTokenInterfaces.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LeveredPositionStorage {
  // @notice the base collateral is the amount of collateral that is not funded by borrowing stables
  uint256 public baseCollateral;
  address public immutable positionOwner;
  ILeveredPositionFactory public factory;

  ICErc20 public collateralMarket;
  ICErc20 public stableMarket;
  IComptroller public pool;

  IERC20Upgradeable public collateralAsset;
  IERC20Upgradeable public stableAsset;

  constructor (address _positionOwner) {
    positionOwner = _positionOwner;
  }
}