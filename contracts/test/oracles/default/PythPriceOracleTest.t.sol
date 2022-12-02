// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PythPriceOracle } from "../../../oracles/default/PythPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";
import { MockPyth } from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { Pyth } from "pyth-neon/PythOracle.sol";

contract PythOraclesTest is BaseTest {
  PythPriceOracle oracle;
  MockPyth pythOracle;

  bytes32 nativeTokenPriceFeed = bytes32(bytes("7f57ca775216655022daa88e41c380529211cde01a1517735dbcf30e4a02bdaa"));
  int64 nativeTokenPrice = 0.5e18;
  bytes32 tokenPriceFeed = bytes32(bytes("41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722"));
  int64 tokenPrice = 1e18;
  address token = 0x7ff459CE3092e8A866aA06DA88D291E2E31230C1;

  function afterForkSetUp() internal override {
    pythOracle = new MockPyth(0);

    PythStructs.PriceFeed memory mockTokenFeed = PythStructs.PriceFeed(
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

    PythStructs.PriceFeed memory mockNativeTokenFeed = PythStructs.PriceFeed(
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
    feedData[0] = abi.encode(mockTokenFeed);
    feedData[1] = abi.encode(mockNativeTokenFeed);
    pythOracle.updatePriceFeeds(feedData);

    oracle = new PythPriceOracle();
    oracle.initialize(
      true,
      address(0),
      address(pythOracle),
      nativeTokenPriceFeed,
      MasterPriceOracle(address(0)),
      address(0)
    );
  }

  function getPrice(address testedTokenAddress, bytes32 feedId) internal returns (uint256 price) {
    address[] memory underlyings = new address[](1);
    underlyings[0] = testedTokenAddress;
    bytes32[] memory feedIds = new bytes32[](1);
    feedIds[0] = feedId;
    oracle.setPriceFeeds(underlyings, feedIds);

    price = oracle.price(testedTokenAddress);
  }

  function testTokenPrice() public fork(NEON_DEVNET) {
    assertEq(getPrice(token, tokenPriceFeed), uint256(uint64((tokenPrice / nativeTokenPrice) * 1e18)));
  }
}
