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
  IAdrastiaPriceOracle private feed;
  address gUSDC = 0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687;
  address axlWETH = 0x50dE24B3f0B3136C50FA8A3B8ebc8BD80a269ce5;

  function setUpWithNativeFeed() public {
    oracle = new AdrastiaPriceOracle();

    // https://docs.adrastia.io/deployments/evmos
    feed = IAdrastiaPriceOracle(0xd850F64Eda6a62d625209711510f43cD49Ef8798);
    emit log_named_address("feed", address(feed));
    emit log_named_uint("dec", feed.quoteTokenDecimals());
    emit log_named_address("address", address(feed.quoteTokenAddress()));
    vm.prank(oracle.owner());
    oracle.initialize(address(0), IAdrastiaPriceOracle(0xd850F64Eda6a62d625209711510f43cD49Ef8798));
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
    // XXX/WEVMOS on EVMOS mainnet
    IAdrastiaPriceOracle evmosBasedFeed = IAdrastiaPriceOracle(0x51d3d22965Bb2CB2749f896B82756eBaD7812b6d);
    address[] memory underlyings = new address[](2);
    underlyings[0] = gUSDC;
    underlyings[1] = axlWETH;

    IAdrastiaPriceOracle[] memory priceFeeds = new IAdrastiaPriceOracle[](2);
    priceFeeds[0] = evmosBasedFeed;
    priceFeeds[1] = evmosBasedFeed;

    vm.prank(oracle.owner());
    oracle.setPriceFeeds(underlyings, priceFeeds);
  }

  function testAdrastiaPriceOracleWithNativeFeed() public fork(EVMOS_MAINNET) {
    setUpWithNativeFeed();
    setUpOracles();
    uint256 priceGUsdc = oracle.price(gUSDC);
    emit log_uint(priceGUsdc);
    assertEq(priceGUsdc, 217398180292000000000);

    uint256 priceEth = oracle.price(axlWETH);
    emit log_uint(priceEth);
    assertEq(priceEth, 217398180292000000000);
  }

  function testAdrastiaPriceOracleWithMasterPriceOracle() public fork(EVMOS_MAINNET) {
    setUpWithMasterPriceOracle();
    setUpOracles();
    vm.prank(address(mpo));
    uint256 price = oracle.price(address(1));
    assertEq(price, 217398180292000000000);
  }
}
