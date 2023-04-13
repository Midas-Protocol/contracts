// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../DiamondExtension.sol";
import { LeveredVaultStorage } from "./LeveredVaultStorage.sol";

contract LeveredVaultBase is LeveredVaultStorage, DiamondBase {
  /**
 * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) public override {
    require(msg.sender == owner(), "!unauthorized - no admin rights");
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }

}