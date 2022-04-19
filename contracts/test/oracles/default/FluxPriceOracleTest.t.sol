// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import {FluxPriceOracle} from "../../../oracles/default/FluxPriceOracle.sol";
import {CLV2V3Interface} from "../../../external/flux/CLV2V3Interface.sol";
import {MockFluxPriceFeed} from "../../mocks/flux/MockFluxPriceFeed.sol";

contract FluxPriceOracleTest is BaseTest {
  FluxPriceOracle private oracle;

  function setUp() public {
    CLV2V3Interface ethPool = CLV2V3Interface(0xf8af20b210bCed918f71899E9f4c26dE53e6ccE6);
    MockFluxPriceFeed mock = new MockFluxPriceFeed(5 * 10**8); // 5 USD in 8 decimals
    oracle = new FluxPriceOracle(address(this), true, address(0), address(mock));
    
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(1);
    CLV2V3Interface[] memory priceFeeds = new CLV2V3Interface[](1);
    priceFeeds[0] = ethPool;
    oracle.setPriceFeeds(underlyings, priceFeeds);
  }

  function testFluxPriceOracle() shouldRun(forChains(EVMOS_TESTNET)) public {
    uint256 price = oracle.price(address(1));
    emit log_uint(price);
  }
}
