// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../contracts/external/jarvis/ISynthereumLiquidityPool.sol";
import "../contracts/oracles/default/ChainlinkPriceOracleV2.sol";

contract SynthereumChainlinkOracleTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);
  address jBRLAddress = 0x316622977073BBC3dF32E7d2A9B3c77596a0a603;
  address jBRLAggregator = 0x5cb1Cb3eA5FB46de1CE1D0F3BaDB3212e8d8eF48;

  function testPriceFeed() public {
//    ISynthereumLiquidityPool pool = ISynthereumLiquidityPool(0x0fD8170Dc284CD558325029f6AEc1538c7d99f49);
//    bytes32 feedId = pool.getPriceFeedIdentifier();
//    emit log_bytes32(feedId);
//    address implementation = pool.synthereumFinder().getImplementationAddress(keccak256('PriceFeed'));
//    emit log_address(implementation);
    ChainlinkPriceOracleV2 oracle = ChainlinkPriceOracleV2(0xb87bC7F78F8c87d37e6FA2abcADF4C6Da0bc124A);

    address[] memory underlyings = new address[](1);
    underlyings[0] = jBRLAddress;
    AggregatorV3Interface[] memory aggregators = new AggregatorV3Interface[](1);
    AggregatorV3Interface feed = AggregatorV3Interface(jBRLAggregator);
    aggregators[0] = feed;

    (, int256 tokenEthPrice, , , ) = feed.latestRoundData();

    emit log_int(tokenEthPrice);
    uint256 result = tokenEthPrice >= 0 ? (uint256(tokenEthPrice) * 1e18) / (10**uint256(feed.decimals())) : 0;
    emit log_uint(result);

    vm.prank(oracle.admin());
    oracle.setPriceFeeds(underlyings, aggregators, ChainlinkPriceOracleV2.FeedBaseCurrency.USD);

    uint256 price = oracle.price(jBRLAddress);
    emit log_uint(price);
  }
}
