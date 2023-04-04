// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { VaultFees, IERC20 } from "./IVault.sol";
import "../strategies/CompoundMarketERC4626.sol";
import "../DiamondExtension.sol";
import { MidasFlywheel } from "../strategies/flywheel/MidasFlywheel.sol";

struct AdapterConfig {
  CompoundMarketERC4626 adapter;
  uint64 allocation;
}

abstract contract MultiStrategyVaultStorage is DiamondBase {
  uint8 internal _decimals;
  string internal _name;
  string internal _symbol;

  bytes32 public contractName;

  uint256 public highWaterMark;
  uint256 public assetsCheckpoint;
  uint256 public feesUpdatedAt;

  VaultFees public fees;
  VaultFees public proposedFees;
  uint256 public proposedFeeTime;
  address public feeRecipient;

  AdapterConfig[10] public adapters;
  AdapterConfig[10] public proposedAdapters;
  uint8 public adapterCount;
  uint8 public proposedAdapterCount;
  uint256 public proposedAdapterTime;

  uint256 public quitPeriod;
  uint256 public depositLimit;

  uint256 internal INITIAL_CHAIN_ID;
  bytes32 internal INITIAL_DOMAIN_SEPARATOR;
  mapping(address => uint256) public nonces;



  bool public emergencyExit;
  uint256 public withdrawalThreshold;
  address public registry;
  mapping(IERC20 => MidasFlywheel) public flywheelForRewardToken;
  address public flywheelLogic;

  function owner() public view virtual returns (address);

  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) external override {
    require(msg.sender == owner(), "!unauthorized - no admin rights");
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }

}
