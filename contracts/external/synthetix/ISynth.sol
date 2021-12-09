// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

interface ISynth {
    function currencyKey() external view returns (bytes32);
}
