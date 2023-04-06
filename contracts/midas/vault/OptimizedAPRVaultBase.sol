// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../DiamondExtension.sol";
import { OptimizedAPRVaultStorage, VaultFees, AdapterConfig } from "./OptimizedAPRVaultStorage.sol";
import { OptimizedAPRVaultFirstExtension } from "./OptimizedAPRVaultFirstExtension.sol";
import { OptimizedAPRVaultSecondExtension } from "./OptimizedAPRVaultSecondExtension.sol";

import { IERC20MetadataUpgradeable as IERC20Metadata } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract OptimizedAPRVaultBase is OptimizedAPRVaultStorage, DiamondBase {
  // IMPORTANT: do not use this contract for storage/variables
  //uint256[50] private __pausableGap;
  //uint256[50] private __reentrancyGuardGap;
  //uint256[51] private __erc4626Gap;
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

  function initialize(DiamondExtension[] calldata extensions) public {
    _transferOwnership(msg.sender);
    for (uint256 i; i < extensions.length; i++)
      LibDiamond.registerExtension(extensions[i], DiamondExtension(address(0)));
  }
}
