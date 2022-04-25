// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../../external/flux/CLV2V3Interface.sol";

contract MockFluxPriceFeed {
  int256 public staticPrice;

  constructor (int256 _staticPrice) {
    staticPrice = _staticPrice;
  }

  function latestAnswer() external view returns (int256) {
    return staticPrice;
  }
}
