// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../../oracles/default/ChainlinkPriceOracleV2.sol";
import "../../config/BaseTest.t.sol";

contract ChainlinkOraclesTest is BaseTest {
  ChainlinkPriceOracleV2 oracle;

  address usdNativeFeedPolygon = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;
  address usdcPolygon = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  address usdtPolygon = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
  address usdcFeedPolygon = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
  address usdtFeedPolygon = 0x0A6513e40db6EB1b165753AD52E80663aeA50545;
  ICToken usdcMarketPolygon = ICToken(0xEf335e0faC86fe2860e7fC2cc620Adad094F3eF4);

  address usdNativeFeedBsc = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
  address jBRLBsc = 0x316622977073BBC3dF32E7d2A9B3c77596a0a603;
  address jBRLFeedBsc = 0x5cb1Cb3eA5FB46de1CE1D0F3BaDB3212e8d8eF48;
  address usdcBsc = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
  address usdtBsc = 0x55d398326f99059fF775485246999027B3197955;
  address usdtFeedBsc = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320;
  address usdcFeedBsc = 0x51597f405303C4377E36123cBc172b13269EA163;
  ICToken usdcMarketBsc = ICToken(0x8D5bE2768c335e88b71E4e913189AEE7104f01B4);
  ICToken usdtMarketBsc = ICToken(0x1F73754c135d5B9fDE674806f43AeDfA2c7eaDb5);

  function setUp() public {
    oracle = ChainlinkPriceOracleV2(ap.getAddress("ChainlinkPriceOracleV2"));
  }

  function setUpOracleFeed(address testedTokenAddress, address aggregatorAddress) internal {
    address[] memory underlyings = new address[](1);
    underlyings[0] = testedTokenAddress;
    AggregatorV3Interface[] memory aggregators = new AggregatorV3Interface[](1);
    AggregatorV3Interface feed = AggregatorV3Interface(aggregatorAddress);
    aggregators[0] = feed;

    vm.prank(oracle.admin());
    oracle.setPriceFeeds(underlyings, aggregators, ChainlinkPriceOracleV2.FeedBaseCurrency.USD);
  }

  function testPolygonChainlinkUSDCPrice() public shouldRun(forChains(POLYGON_MAINNET)) {
    oracle = new ChainlinkPriceOracleV2(address(this), true, ap.getAddress("wtoken"), usdNativeFeedPolygon);
    setUpOracleFeed(usdcPolygon, usdcFeedPolygon);
    uint256 price = oracle.price(usdcPolygon);
    uint256 underlyingPrice = oracle.getUnderlyingPrice(usdcMarketPolygon);
    assertEq(price, underlyingPrice);
  }

  function testJBRLPrice() public shouldRun(forChains(BSC_MAINNET)) {
    setUpOracleFeed(jBRLBsc, jBRLFeedBsc);
    assert(oracle.price(jBRLBsc) > 0);
  }

  function testBSCChainlinkUSDCPrice() public shouldRun(forChains(BSC_MAINNET)) {
    oracle = new ChainlinkPriceOracleV2(address(this), true, ap.getAddress("wtoken"), usdNativeFeedBsc);
    setUpOracleFeed(usdcBsc, usdcFeedBsc);
    uint256 price = oracle.price(usdcBsc);
    uint256 underlyingPrice = oracle.getUnderlyingPrice(usdcMarketBsc);
    assertEq(price, underlyingPrice);
  }

  function testBSCChainlinkUSDTPrice() public shouldRun(forChains(BSC_MAINNET)) {
    oracle = new ChainlinkPriceOracleV2(address(this), true, ap.getAddress("wtoken"), usdNativeFeedBsc);
    setUpOracleFeed(usdtBsc, usdtFeedBsc);
    uint256 price = oracle.price(usdtBsc);
    uint256 underlyingPrice = oracle.getUnderlyingPrice(usdtMarketBsc);
    assertEq(price, underlyingPrice);
  }

  function testUsdcUsdtDeviationBsc() public shouldRun(forChains(BSC_MAINNET)) {
    setUpOracleFeed(usdtBsc, usdtFeedBsc);
    setUpOracleFeed(usdcBsc, usdcFeedBsc);

    uint256 usdtPrice = oracle.getUnderlyingPrice(usdtMarketBsc);
    uint256 usdcPrice = oracle.getUnderlyingPrice(usdcMarketBsc);

    assertApproxEqAbs(usdtPrice, usdcPrice, 1e15, "usd prices differ too much");
  }

  function testUsdcUsdtDeviationPolygon() public shouldRun(forChains(POLYGON_MAINNET)) {
    setUpOracleFeed(usdtPolygon, usdtFeedPolygon);
    setUpOracleFeed(usdcPolygon, usdcFeedPolygon);

    uint256 usdtPrice = oracle.price(usdtPolygon);
    uint256 usdcPrice = oracle.price(usdcPolygon);

    assertApproxEqAbs(usdtPrice, usdcPrice, 1e15, "usd prices differ too much");
  }
}
