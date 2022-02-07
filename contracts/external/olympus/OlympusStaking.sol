// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.0;

abstract contract OlympusStaking {
    address public OHM;
    function unstake(uint _amount, bool _trigger) external virtual;
}
