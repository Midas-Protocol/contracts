// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../DiamondExtension.sol";
import { OptimizedAPRVaultStorage, VaultFees, AdapterConfig } from "./OptimizedAPRVaultStorage.sol";
import { OptimizedAPRVaultExtension } from "./OptimizedAPRVaultExtension.sol";
import { OptimizedAPRVaultFirstExtension } from "./OptimizedAPRVaultFirstExtension.sol";
import { OptimizedAPRVaultSecondExtension } from "./OptimizedAPRVaultSecondExtension.sol";

import { IERC20MetadataUpgradeable as IERC20Metadata } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

// This contract is not upgradeable, but the storage can be amended for the extensions
contract OptimizedAPRVaultBase is OptimizedAPRVaultStorage, DiamondBase {
  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) public override {
    require(msg.sender == owner(), "!unauthorized - no admin rights");
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }

  // TODO can we unify the two extensions interfaces into one?
  function asFirstExtension() public view returns (OptimizedAPRVaultFirstExtension) {
    return OptimizedAPRVaultFirstExtension(address(this));
  }

  function asSecondExtension() public view returns (OptimizedAPRVaultSecondExtension) {
    return OptimizedAPRVaultSecondExtension(address(this));
  }

  // TODO if only safe ownable is non-initializeable, then covert this to a constructor
  // otherwise, make this a full-config constructor
  function initialize(OptimizedAPRVaultExtension[] calldata extensions, bytes calldata initData) public onlyOwner {
    for (uint256 i; i < extensions.length; i++)
      LibDiamond.registerExtension(extensions[i], DiamondExtension(address(0)));

    asFirstExtension().initialize(initData);
  }
}
