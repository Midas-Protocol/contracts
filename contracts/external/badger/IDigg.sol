// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

interface IDigg {
    /**
     * @param shares Share value to convert.
     * @return The current fragment value of the specified underlying share amount.
     */
    function sharesToFragments(uint256 shares) external view returns (uint256);
}
