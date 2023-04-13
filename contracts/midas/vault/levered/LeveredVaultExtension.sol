// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./LeveredVaultStorage.sol";
import { DiamondExtension } from "../../DiamondExtension.sol";

abstract contract LeveredVaultExtension is LeveredVaultStorage, DiamondExtension {

}