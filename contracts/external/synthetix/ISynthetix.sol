// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

interface ISynthetix {
    function exchange(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external returns (uint amountReceived);
}
