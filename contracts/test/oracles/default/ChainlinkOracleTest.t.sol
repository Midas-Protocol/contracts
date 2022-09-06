// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../../oracles/default/ChainlinkPriceOracleV2.sol";
import "../../config/BaseTest.t.sol";

contract ChainlinkOraclesTest is BaseTest {
  ChainlinkPriceOracleV2 oracle;

  function setUp() public {
    oracle = ChainlinkPriceOracleV2(ap.getAddress("ChainlinkPriceOracleV2"));
  }

  function testPriceFeed(address testedTokenAddress, address aggregatorAddress) internal returns (uint256 price) {
    address[] memory underlyings = new address[](1);
    underlyings[0] = testedTokenAddress;
    AggregatorV3Interface[] memory aggregators = new AggregatorV3Interface[](1);
    AggregatorV3Interface feed = AggregatorV3Interface(aggregatorAddress);
    aggregators[0] = feed;

    vm.prank(oracle.admin());
    oracle.setPriceFeeds(underlyings, aggregators, ChainlinkPriceOracleV2.FeedBaseCurrency.USD);

    price = oracle.price(testedTokenAddress);
  }

  function testJBRLPrice() public shouldRun(forChains(BSC_MAINNET)) {
    address jBRLAddress = 0x316622977073BBC3dF32E7d2A9B3c77596a0a603;
    address jBRLAggregatorAddress = 0x5cb1Cb3eA5FB46de1CE1D0F3BaDB3212e8d8eF48;

    assert(testPriceFeed(jBRLAddress, jBRLAggregatorAddress) > 0);
  }

  function testLocalChainlinkUSDCPrice() public shouldRun(forChains(POLYGON_MAINNET)) {
    oracle = new ChainlinkPriceOracleV2(
      address(this),
      true,
      0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
      0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
    );
    address USDCAddress = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address USDCAggregatorAddress = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
    uint256 price = testPriceFeed(USDCAddress, USDCAggregatorAddress);
    uint256 underlyingPrice = oracle.getUnderlyingPrice(ICToken(0xEf335e0faC86fe2860e7fC2cc620Adad094F3eF4));
    assertEq(price, underlyingPrice);
  }
}
