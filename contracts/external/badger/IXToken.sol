// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

interface IXToken {
    function pricePerShare() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
}
