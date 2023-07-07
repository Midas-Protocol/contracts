// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";

import { FusePoolLens } from "../FusePoolLens.sol";
import "../compound/ComptrollerInterface.sol";

contract FusePoolLensTest is BaseTest {
  function testPolygonFPL() public debuggingOnly fork(POLYGON_MAINNET) {
    FusePoolLens fpl = FusePoolLens(0xD7225110D8F419b0E8Ad0A536977965E62fB5769);
    fpl.getPoolAssetsWithData(IComptroller(0xB08A309eFBFFa41f36A06b2D0C9a4629749b17a2));
  }

  function testChapelFPL() public debuggingOnly fork(BSC_CHAPEL) {
    FusePoolLens fpl = FusePoolLens(0xD880d5D33221F3992E695f5C6bFBC558e9Ad31cF);
    vm.prank(0x8982aa50bb919E42e9204f12e5b59D053Eb2A602);
    fpl.getPoolAssetsWithData(IComptroller(0x044c436b2f3EF29D30f89c121f9240cf0a08Ca4b));
  }
}
