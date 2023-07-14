// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";

import { PoolLens } from "../PoolLens.sol";
import "../compound/ComptrollerInterface.sol";

contract PoolLensTest is BaseTest {
  function testPolygonFPL() public debuggingOnly fork(POLYGON_MAINNET) {
    PoolLens fpl = PoolLens(0xD7225110D8F419b0E8Ad0A536977965E62fB5769);
    fpl.getPoolAssetsWithData(IComptroller(0xB08A309eFBFFa41f36A06b2D0C9a4629749b17a2));
  }

  function testWhitelistsFPL() public debuggingOnly fork(BSC_CHAPEL) {
    PoolLens fpl = PoolLens(0x604805B587C939042120D2e22398f299547A130c);
    fpl.getSupplyCapsDataForPool(IComptroller(0x307BEc9d1368A459E9168fa6296C1e69025ab30f));
  }
}
