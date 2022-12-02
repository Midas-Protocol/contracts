// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CToken.sol";

/**
 * @title Compound's CEther Contract
 * @notice CToken which wraps Ether
 * @dev This contract should not to be deployed on its own; instead, deploy `CEtherDelegator` (proxy contract) and `CEtherDelegate` (logic/implementation contract).
 * @author Compound
 */
contract CEther is CToken {
  bool public constant override isCEther = true;

  /*** Safe Token ***/

  /**
   * @notice Gets balance of this contract in terms of Ether, before this message
   * @dev This excludes the value of the current message, if any
   * @return The quantity of Ether owned by this contract
   */
  function getCashPrior() internal view override returns (uint256) {
    (MathError err, uint256 startingBalance) = subUInt(address(this).balance, msg.value);
    require(err == MathError.NO_ERROR);
    return startingBalance;
  }

  /**
   * @notice Perform the actual transfer in, which is a no-op
   * @param from Address sending the Ether
   * @param amount Amount of Ether being sent
   * @return The actual amount of Ether transferred
   */
  function doTransferIn(address from, uint256 amount) internal override returns (uint256) {
    // Sanity checks
    require(msg.sender == from, "sender mismatch");
    require(msg.value == amount, "value mismatch");
    return amount;
  }

  function doTransferOut(address to, uint256 amount) internal override {
    // Send the Ether and revert on failure
    (bool success, ) = to.call{ value: amount }("");
    require(success, "doTransferOut failed");
  }
}
