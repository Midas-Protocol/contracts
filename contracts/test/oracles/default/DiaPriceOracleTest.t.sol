// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import { DiaPriceOracle, DIAOracleV2 } from "../../../oracles/default/DiaPriceOracle.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";

contract MockDiaPriceFeed is DIAOracleV2 {
  struct DiaOracle {
    DIAOracleV2 feed;
    string key;
  }

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
  MasterPriceOracle masterPriceOracle;

  function testMoonbeam() public forkAtBlock(MOONBEAM_MAINNET, 1824921) {
    testDiaPriceOracleWithNativeFeedMoonbeam();
    testDiaPriceOracleWithMasterPriceOracleMoonbeam();
  }

  function testBsc() public forkAtBlock(BSC_MAINNET, 20238373) {
    testDiaPriceOracleWithMasterPriceOracleBsc();
  }

  function setUpWithNativeFeed() internal {
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

  function setUpWithMasterPriceOracle() internal {
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

  function setUpOraclesMoonbeam() internal {
    DIAOracleV2 ethPool = DIAOracleV2(0x1f1BAe8D7a2957CeF5ffA0d957cfEDd6828D728f);
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(1);
    DIAOracleV2[] memory priceFeeds = new DIAOracleV2[](1);
    priceFeeds[0] = ethPool;
    string[] memory keys = new string[](1);
    keys[0] = "ETH/USD";
    oracle.setPriceFeeds(underlyings, priceFeeds, keys);
  }

  function testDiaPriceOracleWithNativeFeedMoonbeam() internal {
    setUpWithNativeFeed();
    setUpOraclesMoonbeam();
    uint256 price = oracle.price(address(1));
    assertEq(price, 325929279276000000000);
  }

  function testDiaPriceOracleWithMasterPriceOracleMoonbeam() internal {
    setUpWithMasterPriceOracle();
    setUpOraclesMoonbeam();
    uint256 price = oracle.price(address(1));
    assertEq(price, 325929279276000000000);
  }

  function testDiaPriceOracleWithMasterPriceOracleBsc() internal {
    oracle = DiaPriceOracle(0x944e833dC2Af9fc58D5cfA99B9D8666c843Ad58C);

    // miMATIC (MAI)
    uint256 price = oracle.price(0x3F56e0c36d275367b8C502090EDF38289b3dEa0d);
    assertApproxEqAbs(price, 3086017057904017, 1e14);
    masterPriceOracle = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));

    // compare to BUSD, ensure price does not deviate too much
    uint256 priceBusd = masterPriceOracle.price(ap.getAddress("bUSD"));
    assertApproxEqAbs(price, priceBusd, 1e14);
  }
}
