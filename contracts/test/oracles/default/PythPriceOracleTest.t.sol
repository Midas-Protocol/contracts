// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../../oracles/default/PythPriceOracle.sol";
import "../../config/BaseTest.t.sol";
import { MockPyth } from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { Pyth } from "pyth-neon/PythOracle.sol";

contract PythOraclesTest is BaseTest {
  PythPriceOracle oracle;
  MockPyth pythOracle;
  
  bytes32 nativeTokenPriceFeed = bytes32(bytes("7f57ca775216655022daa88e41c380529211cde01a1517735dbcf30e4a02bdaa"));
  int64 nativeTokenPrice = 0.5e18;
  bytes32 tokenPriceFeed = bytes32(bytes("ca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6"));
  int64 tokenPrice = 1e18;

  address token = 0x65976a250187cb1D21b7e3693aCF102d61c86177;

  function setUp() public {
    pythOracle = new MockPyth(0);

    PythStructs.PriceFeed memory mockFeed = PythStructs.PriceFeed(
      tokenPriceFeed,
      tokenPriceFeed,
      tokenPrice,
      0,
      0,
      PythStructs.PriceStatus.TRADING,
      0,
      0,
      0,
      0,
      uint64(block.timestamp),
      0,
      0,
      0
    );

    PythStructs.PriceFeed memory mockFeed1 = PythStructs.PriceFeed(
      nativeTokenPriceFeed,
      nativeTokenPriceFeed,
      nativeTokenPrice,
      0,
      0,
      PythStructs.PriceStatus.TRADING,
      0,
      0,
      0,
      0,
      uint64(block.timestamp),
      0,
      0,
      0
    );

    bytes[] memory feedData = new bytes[](2);
    feedData[0] = abi.encode(mockFeed);
    feedData[1] = abi.encode(mockFeed1);
    pythOracle.updatePriceFeeds(feedData);

    oracle = new PythPriceOracle(
      address(this),
      true,
      address(0),
      address(pythOracle),
      nativeTokenPriceFeed,
      MasterPriceOracle(address(0)),
      address(0)
    );
  }

  function testPriceFeed(address testedTokenAddress, bytes32 feedId) internal returns (uint256 price) {
    address[] memory underlyings = new address[](1);
    underlyings[0] = testedTokenAddress;
    bytes32[] memory feedIds = new bytes32[](1);
    feedIds[0] = feedId;
    oracle.setPriceFeeds(underlyings, feedIds);

    price = oracle.price(testedTokenAddress);
  }

  function testTokenPrice() public shouldRun(forChains(NEON_DEVNET)) {
    assertEq(testPriceFeed(token, tokenPriceFeed), uint256(uint64(tokenPrice / nativeTokenPrice * 1e18)));
  }
}
