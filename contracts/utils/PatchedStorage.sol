// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

contract PatchedStorage {
  // keep these storage vars to offset a past storage layout mistake
  address[4] private __gapVars;

  function _resetGap() public {
    __gapVars[0] = address(0);
    __gapVars[1] = address(0);
    __gapVars[2] = address(0);
    __gapVars[3] = address(0);
  }
}
