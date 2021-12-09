// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

interface ExchangeRates {
    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external view returns (uint value);
}
