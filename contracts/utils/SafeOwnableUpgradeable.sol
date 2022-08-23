// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

abstract contract SafeOwnableUpgradeable is OwnableUpgradeable {

    // keep these storage vars to offset a past storage layout mistake
    address[4] private __gapVars;

    function _resetGap() public onlyOwner {
        __gapVars[0] = address(0);
        __gapVars[1] = address(0);
        __gapVars[2] = address(0);
        __gapVars[3] = address(0);
        pendingOwner = address(0);
    }

    address public pendingOwner;

    /**
     * @notice Emitted when pendingOwner is changed
     */
    event NewPendingOwner(address oldPendingOwner, address newPendingOwner);

    /**
     * @notice Emitted when pendingOwner is accepted, which means owner is updated
     */
    event NewOwner(address oldOwner, address newOwner);

    /**
     * @notice Begins transfer of owner rights. The newPendingOwner must call `_acceptOwner` to finalize the transfer.
     * @dev Owner function to begin change of owner. The newPendingOwner must call `_acceptOwner` to finalize the transfer.
     * @param newPendingOwner New pending owner.
     */
    function _setPendingOwner(address newPendingOwner) public onlyOwner {
        // Save current value, if any, for inclusion in log
        address oldPendingOwner = pendingOwner;

        // Store pendingOwner with value newPendingOwner
        pendingOwner = newPendingOwner;

        // Emit NewPendingOwner(oldPendingOwner, newPendingOwner)
        emit NewPendingOwner(oldPendingOwner, newPendingOwner);
    }

    /**
     * @notice Accepts transfer of owner rights. msg.sender must be pendingOwner
     * @dev Owner function for pending owner to accept role and update owner
     */
    function _acceptOwner() public {
        // Check caller is pendingOwner and pendingOwner ≠ address(0)
        require(msg.sender == pendingOwner, "not the pending owner");

        // Save current values for inclusion in log
        address oldOwner = owner();
        address oldPendingOwner = pendingOwner;

        // Store owner with value pendingOwner
        _transferOwnership(pendingOwner);

        // Clear the pending value
        pendingOwner = address(0);

        emit NewOwner(oldOwner, pendingOwner);
        emit NewPendingOwner(oldPendingOwner, pendingOwner);
    }

    function renounceOwnership() public override onlyOwner {
        revert("not used anymore");
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        revert("not used anymore");
    }
}
