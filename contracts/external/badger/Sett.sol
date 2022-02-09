// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

interface Sett {
    function totalSupply() external view returns (uint256);
    function withdrawAll() external;
    function token() external view returns (address);
}
