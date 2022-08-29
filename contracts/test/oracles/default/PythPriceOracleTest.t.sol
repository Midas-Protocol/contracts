// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../../oracles/default/PythPriceOracle.sol";
import "../../config/BaseTest.t.sol";
import { Pyth } from "pyth-neon/PythOracle.sol";

contract PythOraclesTest is BaseTest {
  PythPriceOracle oracle;
  Pyth pythOracle;

  function setUp() public {
    pythOracle = Pyth(0x22a60682c2ACe5CbE57433De0BBAc292107Ca5b2);
    emit log_address(address(pythOracle));
    oracle = new PythPriceOracle(
      address(this),
      true,
      address(0),
      address(pythOracle),
      bytes32(bytes("7f57ca775216655022daa88e41c380529211cde01a1517735dbcf30e4a02bdaa")),
      MasterPriceOracle(address(0)),
      address(0)
    );
    // oracle = PythPriceOracle(ap.getAddress("PythPriceOracle"));
  }

  function testPriceFeed(address testedTokenAddress, bytes32 feedId) internal returns (uint256 price) {
    address[] memory underlyings = new address[](1);
    underlyings[0] = testedTokenAddress;
    bytes32[] memory feedIds = new bytes32[](1);
    feedIds[0] = feedId;
    emit log_uint(1);
    oracle.setPriceFeeds(underlyings, feedIds);
    emit log_uint(111);
    price = oracle.price1(testedTokenAddress);
    emit log_uint(price);
  }

  function testwETHPrice() public shouldRun(forChains(NEON_DEVNET)) {
    address wETH = 0x65976a250187cb1D21b7e3693aCF102d61c86177;
    bytes32 wETH_PRICE_FEED = 0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6;
    // emit log_bytes(wETH_PRICE_FEED);
    // emit log_bytes32(bytes32(bytes(wETH_PRICE_FEED)));

    assert(testPriceFeed(wETH, wETH_PRICE_FEED) > 0);
  }
}
