// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { SafeOwnable } from "../../../midas/SafeOwnable.sol";
import "../../../compound/CErc20.sol";
import { ICErc20 } from "../../../external/compound/ICErc20.sol";
import { IERC20Upgradeable as IERC20 } from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";

contract LeveredVaultStorage is SafeOwnable {
  ICErc20 public collateral;
  IERC20[] public whitelistedCollateralUnderlying; // TODO
  IERC20[] public borrowable;
}
