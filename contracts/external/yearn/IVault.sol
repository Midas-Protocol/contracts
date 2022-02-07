// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IVault {
    function getPricePerFullShare() external view returns (uint);
    function token() external view returns (address);
    function decimals() external view returns (uint8);
    function deposit(uint _amount) external;
    function withdraw(uint _shares) external;
}
