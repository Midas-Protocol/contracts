// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";

import { FusePoolLens } from "../FusePoolLens.sol";
import "../external/compound/IComptroller.sol";

contract FusePoolLensTest is BaseTest {
  function testFPL() public debuggingOnly fork(POLYGON_MAINNET) {
    FusePoolLens fpl = FusePoolLens(0xD7225110D8F419b0E8Ad0A536977965E62fB5769);
    fpl.getPoolAssetsWithData(IComptroller(0xD265ff7e5487E9DD556a4BB900ccA6D087Eb3AD2));
  }
}
