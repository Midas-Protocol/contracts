// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { UmbrellaPriceOracle } from "../../../oracles/default/UmbrellaPriceOracle.sol";
import { IRegistry } from "../../../external/umbrella/IRegistry.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BasePriceOracle } from "../../../oracles/BasePriceOracle.sol";

contract UmbrellaPriceOracleTest is BaseTest {
  UmbrellaPriceOracle private oracle;
  IRegistry public registry;
  MasterPriceOracle mpo;
  address stableToken;
  address otherToken;

  function setUpPolygon() public {
    registry = IRegistry(0x455acbbC2c15c086978083968a69B2e7E4d38d34);
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new UmbrellaPriceOracle();
    vm.prank(mpo.admin());
    oracle.initialize("MATIC-USD", registry);

    address[] memory underlyings = new address[](2);
    string[] memory feeds = new string[](2);

    stableToken = ap.getAddress("stableToken");
    // DAI
    otherToken = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

    underlyings[0] = stableToken;
    underlyings[1] = otherToken;

    feeds[0] = "USDC-USD";
    feeds[1] = "DAI-USD";

    vm.prank(oracle.owner());
    oracle.setPriceFeeds(underlyings, feeds);

    BasePriceOracle[] memory oracles = new BasePriceOracle[](2);
    oracles[0] = oracle;
    oracles[1] = oracle;

    vm.prank(mpo.admin());
    mpo.add(underlyings, oracles);
  }

  function testUmbrellaPriceOracleBsc() public fork(POLYGON_MAINNET) {
    setUpPolygon();
    vm.startPrank(address(mpo));
    uint256 upoBudsPrice = oracle.price(stableToken);
    uint256 mpoBusdPrice = mpo.price(stableToken);

    assertApproxEqRel(upoBudsPrice, mpoBusdPrice, 1e16);

    uint256 upoDaiPrice = oracle.price(otherToken);
    uint256 mpoDaiPrice = mpo.price(otherToken);

    assertApproxEqRel(upoDaiPrice, mpoDaiPrice, 1e16);

    vm.stopPrank();
  }
}
