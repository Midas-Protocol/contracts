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

  function setUpWithNativeFeed() public {
    MockFluxPriceFeed mock = new MockFluxPriceFeed(5 * 10**8); // 5 USD in 8 decimals
    oracle = new FluxPriceOracle(
      address(this),
      true,
      address(0),
      CLV2V3Interface(address(mock)),
      MasterPriceOracle(address(0)),
      address(0)
    );
  }

  function setUpOracles() internal {
    CLV2V3Interface ethPool = CLV2V3Interface(0xf8af20b210bCed918f71899E9f4c26dE53e6ccE6);
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(1);
    CLV2V3Interface[] memory priceFeeds = new CLV2V3Interface[](1);
    priceFeeds[0] = ethPool;
    oracle.setPriceFeeds(underlyings, priceFeeds);
  }

  function testFluxPriceOracleWithNativeFeed() public forkAtBlock(EVMOS_TESTNET, 2940378) {
    setUpWithNativeFeed();
    setUpOracles();
    uint256 price = oracle.price(address(1));
    emit log_uint(price);
    assertEq(price, 243373091628000000000);
  }

  function setUpWithMasterPriceOracle() internal {
    SimplePriceOracle spo = new SimplePriceOracle();
    spo.setDirectPrice(address(2), 200000000000000000); // 1e36 / 200000000000000000 = 5e18
    MasterPriceOracle mpo = new MasterPriceOracle();
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(2);
    IPriceOracle[] memory oracles = new IPriceOracle[](1);
    oracles[0] = IPriceOracle(address(spo));
    mpo.initialize(underlyings, oracles, IPriceOracle(address(spo)), address(this), true, address(0));
    oracle = new FluxPriceOracle(address(this), true, address(0), CLV2V3Interface(address(0)), mpo, address(2));
  }

  function testFluxPriceOracleWithMasterPriceOracle() public forkAtBlock(EVMOS_TESTNET, 2940378) {
    setUpWithMasterPriceOracle();
    setUpOracles();
    uint256 price = oracle.price(address(1));
    assertEq(price, 243373091628000000000);
  }
}
