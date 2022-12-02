// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CEther.sol";
import "./CDelegateInterface.sol";

/**
 * @title Compound's CEtherDelegate Contract
 * @notice CTokens which wrap Ether and are delegated to
 * @author Compound
 */
// TODO remove this contract from the codebase
contract CEtherDelegate is CDelegateInterface, CEther {
  /**
   * @notice Called by the delegator on a delegate to initialize it for duty
   * @param data The encoded bytes data for any initialization
   */
  function _becomeImplementation(bytes memory data) public override {
    require(msg.sender == address(this) || hasAdminRights(), "only self and admins can call _becomeImplementation");
  }

  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationSafe(
    address implementation_,
    bool allowResign,
    bytes calldata becomeImplementationData
  ) external override {
    // Check admin rights
    require(hasAdminRights(), "!admin");
  }

  /**
   * @notice Function called before all delegator functions
   * @dev Checks comptroller.autoImplementation and upgrades the implementation if necessary
   */
  function _prepare() external payable override {}

  function contractType() external pure override returns (string memory) {
    return "CEtherDelegate";
  }
}
