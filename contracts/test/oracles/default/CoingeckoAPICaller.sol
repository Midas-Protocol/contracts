// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

contract CoingeckoAPICaller is Test {
  string internal constant COINGECKO_BASE_URL = "https://api.coingecko.com/api/v3/simple/price?vs_currencies=";
  string internal constant PRECISION_QUERY_URL = "&precision=18&ids=";

  function getCoinGeckoPrice(string memory asset, string memory base) internal returns (uint256) {
    string memory url = concat4(COINGECKO_BASE_URL, base, PRECISION_QUERY_URL, asset);
    string[] memory command = new string[](2);
    command[0] = "curl";
    command[1] = url;

    string memory response = string(vm.ffi(command));
    emit log_named_string("response", response);
    string memory jqFilter = concat4(".", asset, ".", base);
    string memory floatPointPrice = string(vm.parseJsonString(response, jqFilter));
    return floatPointToUint(floatPointPrice);
  }

  function concat4(string memory str0, string memory str1, string memory str2, string memory str3) internal returns (string memory) {
    return string(
      bytes.concat(
        bytes.concat(bytes(str0), bytes(str1)),
        bytes.concat(bytes(str2), bytes(str3))
      )
    );
  }

  function floatPointToUint(string memory str) internal returns (uint256) {
    bytes memory asBytes = bytes(str);
    uint256 k;

    for (uint256 i = 0; i < asBytes.length; i++) {
      if (asBytes[i] != '.') k++;
    }

    bytes memory noPointBytes = new bytes(k);
    k = 0;
    for (uint256 i = 0; i < asBytes.length; i++) {
      if (asBytes[i] != '.') noPointBytes[k++] = asBytes[i];
    }

    return vm.parseUint(string(noPointBytes));
  }
}
