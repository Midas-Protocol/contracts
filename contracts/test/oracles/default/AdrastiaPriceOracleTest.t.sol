// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { AdrastiaPriceOracle } from "../../../oracles/default/AdrastiaPriceOracle.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { IPriceOracle as IAdrastiaPriceOracle } from "adrastia/interfaces/IPriceOracle.sol";

contract AdrastiaPriceOracleTest is BaseTest {
  AdrastiaPriceOracle private oracle;
  MasterPriceOracle private mpo;

  function setUpWithNativeFeed() public {
    oracle = new AdrastiaPriceOracle();
    vm.prank(oracle.owner());
    // https://docs.adrastia.io/deployments/evmos
    oracle.initialize(address(0), IAdrastiaPriceOracle(0x76560102714FDDff1AC8b53e138A220B44873F29));
  }

  function setUpWithMasterPriceOracle() public {
    SimplePriceOracle spo = new SimplePriceOracle();
    spo.setDirectPrice(address(2), 200000000000000000); // 1e36 / 200000000000000000 = 5e18

    mpo = new MasterPriceOracle();
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(2);
    IPriceOracle[] memory oracles = new IPriceOracle[](1);
    oracles[0] = IPriceOracle(address(spo));
    mpo.initialize(underlyings, oracles, IPriceOracle(address(spo)), address(this), true, address(0));

    oracle = new AdrastiaPriceOracle();
    vm.prank(oracle.owner());
    oracle.initialize(address(2), IAdrastiaPriceOracle(address(0)));
  }

  function setUpOracles() public {
    // gUSDC/WEVMOS on EVMOS mainnet
    IAdrastiaPriceOracle gUSD = IAdrastiaPriceOracle(0x3b28D068e55E72355d726E7836a130C0918E9c0E);
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(1);
    IAdrastiaPriceOracle[] memory priceFeeds = new IAdrastiaPriceOracle[](1);
    priceFeeds[0] = gUSD;
    vm.prank(oracle.owner());
    oracle.setPriceFeeds(underlyings, priceFeeds);
  }

  function testAdrastiaPriceOracleWithNativeFeed() public fork(EVMOS_MAINNET) {
    setUpWithNativeFeed();
    setUpOracles();
    uint256 price = oracle.price(address(1));
    emit log_uint(price);
    assertEq(price, 217398180292000000000);
  }

  function testAdrastiaPriceOracleWithMasterPriceOracle() public fork(EVMOS_MAINNET) {
    setUpWithMasterPriceOracle();
    setUpOracles();
    vm.prank(address(mpo));
    uint256 price = oracle.price(address(1));
    assertEq(price, 217398180292000000000);
  }
}
