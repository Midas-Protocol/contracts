// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../contracts/external/jarvis/ISynthereumLiquidityPool.sol";
import "../contracts/oracles/default/ChainlinkPriceOracleV2.sol";

contract SynthereumChainlinkOracleTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);
  address jBRLAddress = 0x316622977073BBC3dF32E7d2A9B3c77596a0a603;
  address jBRLAggregatorAddress = 0x5cb1Cb3eA5FB46de1CE1D0F3BaDB3212e8d8eF48;
  address bscMainnetChainlinkOracleAddress = 0xb87bC7F78F8c87d37e6FA2abcADF4C6Da0bc124A;

  function testPriceFeed() public {
    ChainlinkPriceOracleV2 oracle = ChainlinkPriceOracleV2(bscMainnetChainlinkOracleAddress);

    address[] memory underlyings = new address[](1);
    underlyings[0] = jBRLAddress;
    AggregatorV3Interface[] memory aggregators = new AggregatorV3Interface[](1);
    AggregatorV3Interface feed = AggregatorV3Interface(jBRLAggregatorAddress);
    aggregators[0] = feed;

    vm.prank(oracle.admin());
    oracle.setPriceFeeds(underlyings, aggregators, ChainlinkPriceOracleV2.FeedBaseCurrency.USD);

    uint256 price = oracle.price(jBRLAddress);
    assert(price > 0);
  }
}
