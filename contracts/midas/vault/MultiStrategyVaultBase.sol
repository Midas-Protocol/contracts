// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../DiamondExtension.sol";
import { MultiStrategyVaultStorage, VaultFees, AdapterConfig } from "./MultiStrategyVaultStorage.sol";
import { MultiStrategyVaultFirstExtension } from "./MultiStrategyVaultFirstExtension.sol";
import { MultiStrategyVaultSecondExtension } from "./MultiStrategyVaultSecondExtension.sol";

import { IERC20MetadataUpgradeable as IERC20Metadata } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract MultiStrategyVaultBase is MultiStrategyVaultStorage, DiamondBase {
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
  function asFirstExtension() public view returns (MultiStrategyVaultFirstExtension) {
    return MultiStrategyVaultFirstExtension(address(this));
  }

  function asSecondExtension() public view returns (MultiStrategyVaultSecondExtension) {
    return MultiStrategyVaultSecondExtension(address(this));
  }

  function initialize(DiamondExtension[] calldata extensions) public {
    _transferOwnership(msg.sender);
    for (uint256 i; i < extensions.length; i++) LibDiamond.registerExtension(extensions[i], DiamondExtension(address(0)));
  }
}
