// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../DiamondExtension.sol";
import { LeveredVaultStorage } from "./LeveredVaultStorage.sol";
import "./LeveredVaultExtension.sol";

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

  function asExtension() public view returns (LeveredVaultExtension) {
    return LeveredVaultExtension(address(this));
  }

  function initialize(LeveredVaultExtension[] calldata extensions, bytes calldata initData) public onlyOwner {
    for (uint256 i; i < extensions.length; i++)
      LibDiamond.registerExtension(extensions[i], DiamondExtension(address(0)));

    asExtension().initialize(initData);
  }
}