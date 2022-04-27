// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import { DiaPriceOracle, DIAOracleV2 } from "../../../oracles/default/DiaPriceOracle.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";

contract MockDiaPriceFeed is DIAOracleV2 {
  uint128 public staticPrice;

  constructor(uint128 _staticPrice) {
    staticPrice = _staticPrice;
  }

  function getValue(string memory key) external view returns (uint128, uint128) {
    return (staticPrice, uint128(block.timestamp));
  }
}

contract DiaPriceOracleTest is BaseTest {
  DiaPriceOracle private oracle;

  function setUpWithNativeFeed() public {
    MockDiaPriceFeed mock = new MockDiaPriceFeed(5 * 10**8); // 5 USD in 8 decimals
    oracle = new DiaPriceOracle(
      address(this),
      true,
      address(0),
      mock,
      "GLMR/USD",
      MasterPriceOracle(address(0)),
      address(0)
    );
  }

  function setUpWithMasterPriceOracle() public {
    SimplePriceOracle spo = new SimplePriceOracle();
    spo.setDirectPrice(address(2), 200000000000000000); // 1e36 / 200000000000000000 = 5e18
    MasterPriceOracle mpo = new MasterPriceOracle();
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(2);
    IPriceOracle[] memory oracles = new IPriceOracle[](1);
    oracles[0] = IPriceOracle(address(spo));
    mpo.initialize(underlyings, oracles, IPriceOracle(address(spo)), address(this), true, address(0));
    oracle = new DiaPriceOracle(address(this), true, address(0), MockDiaPriceFeed(address(0)), "", mpo, address(2));
  }

  function setUpOracles() public {
    DIAOracleV2 ethPool = DIAOracleV2(0x1f1BAe8D7a2957CeF5ffA0d957cfEDd6828D728f);
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(1);
    DIAOracleV2[] memory priceFeeds = new DIAOracleV2[](1);
    priceFeeds[0] = ethPool;
    string[] memory keys = new string[](1);
    keys[0] = "ETH/USD";
    oracle.setPriceFeeds(underlyings, priceFeeds, keys);
  }

  function testDiaPriceOracleWithNativeFeed() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    setUpWithNativeFeed();
    setUpOracles();
    uint256 price = oracle.price(address(1));
    assertEq(price, 590620741358000000000);
  }

  function testDiaPriceOracleWithMasterPriceOracle() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    setUpWithMasterPriceOracle();
    setUpOracles();
    uint256 price = oracle.price(address(1));
    assertEq(price, 590620741358000000000);
  }
}
