// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";

import { FusePoolLens } from "../FusePoolLens.sol";
import "../external/compound/IComptroller.sol";

contract FusePoolLensTest is BaseTest {
  function testPolygonFPL() public debuggingOnly fork(POLYGON_MAINNET) {
    FusePoolLens fpl = FusePoolLens(0xD7225110D8F419b0E8Ad0A536977965E62fB5769);
    fpl.getPoolAssetsWithData(IComptroller(0xB08A309eFBFFa41f36A06b2D0C9a4629749b17a2));
  }

  function testWhitelistsFPL() public debuggingOnly fork(BSC_CHAPEL) {
    FusePoolLens fpl = FusePoolLens(0x70DFe506D2C3AfC7EEa40620BAC8ab3f558A84d2);
    fpl.getSupplyCapsDataForPool(IComptroller(0x307BEc9d1368A459E9168fa6296C1e69025ab30f));
  }
}
