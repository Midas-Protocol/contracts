// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { FluxPriceOracle } from "../../../oracles/default/FluxPriceOracle.sol";
import { CLV2V3Interface } from "../../../external/flux/CLV2V3Interface.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";

contract MockFluxPriceFeed {
  int256 public staticPrice;

  constructor(int256 _staticPrice) {
    staticPrice = _staticPrice;
  }

  function latestAnswer() external view returns (int256) {
    return staticPrice;
  }
}

contract FluxPriceOracleTest is BaseTest {
  FluxPriceOracle private oracle;
  MasterPriceOracle private mpo;

  function setUpWithNativeFeed() public {
    MockFluxPriceFeed mock = new MockFluxPriceFeed(5 * 10**8); // 5 USD in 8 decimals
    oracle = new FluxPriceOracle();
    oracle.initialize(address(0), CLV2V3Interface(address(mock)));
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

    oracle = new FluxPriceOracle();
    oracle.initialize(address(2), CLV2V3Interface(address(0)));
  }

  function setUpOracles() public {
    // ETH/USD on EVMOS mainnet
    CLV2V3Interface ethPool = CLV2V3Interface(0x4C8f111a1048fEc7Ea9c9cbAB96a2cB5d1B94560);
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(1);
    CLV2V3Interface[] memory priceFeeds = new CLV2V3Interface[](1);
    priceFeeds[0] = ethPool;
    oracle.setPriceFeeds(underlyings, priceFeeds);
  }

  function testFluxPriceOracleWithNativeFeed() public forkAtBlock(EVMOS_MAINNET, 7527151) {
    setUpWithNativeFeed();
    setUpOracles();
    uint256 price = oracle.price(address(1));
    emit log_uint(price);
    assertEq(price, 217398180292000000000);
  }

  function testFluxPriceOracleWithMasterPriceOracle() public forkAtBlock(EVMOS_MAINNET, 7527151) {
    setUpWithMasterPriceOracle();
    setUpOracles();
    vm.prank(address(mpo));
    uint256 price = oracle.price(address(1));
    assertEq(price, 217398180292000000000);
  }
}
