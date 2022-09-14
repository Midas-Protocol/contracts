// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../../oracles/MasterPriceOracle.sol";
import "../../../oracles/default/UniswapV3PriceOracle.sol";
import "../../../external/uniswap/IUniswapV2Factory.sol";
import "../../../external/uniswap/IUniswapV3Pool.sol";

import "../../config/BaseTest.t.sol";

contract UniswapV3PriceOracleTest is BaseTest {
  UniswapV3PriceOracle oracle;
  MasterPriceOracle mpo;

  struct AssetConfig {
    address poolAddress;
    uint256 twapWindow;
  }

  function setUp() public {
    // oracle = UniswapV3PriceOracle(ap.getAddress("UniswapV3PriceOracle"));
    oracle = new UniswapV3PriceOracle(address(this), true);
  }

  function testPriceFeed(address[] memory underlyings, UniswapV3PriceOracle.AssetConfig[] memory configs)
    internal
    returns (uint256[] memory price)
  {
    vm.prank(oracle.admin());
    oracle.setPoolFeeds(underlyings, configs);
    vm.roll(1);

    price = new uint256[](underlyings.length);
    for (uint256 i = 0; i < underlyings.length; i++) {
      price[i] = oracle.price(underlyings[i]);
    }
    return price;
  }

  function testArbitrumAssets() public shouldRun(forChains(ARBITRUM_ONE)) {
    address[] memory underlyings = new address[](3);
    UniswapV3PriceOracle.AssetConfig[] memory configs = new UniswapV3PriceOracle.AssetConfig[](3);

    underlyings[0] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX
    underlyings[1] = 0x6C2C06790b3E3E3c38e12Ee22F8183b37a13EE55; // DPX
    underlyings[2] = 0x2c852D3334188BE136bFC540EF2bB8C37b590BAD; // MAGIC

    configs[0] = UniswapV3PriceOracle.AssetConfig(0x80A9ae39310abf666A87C743d6ebBD0E8C42158E, 10 minutes); // GMX-ETH
    configs[1] = UniswapV3PriceOracle.AssetConfig(0xb52781C275431bD48d290a4318e338FE0dF89eb9, 10 minutes); // DPX-ETH
    configs[2] = UniswapV3PriceOracle.AssetConfig(0x7e7FB3CCEcA5F2ac952eDF221fd2a9f62E411980, 10 minutes); // MAGIC-ETH
    

    uint256[] memory prices = testPriceFeed(underlyings, configs);
    bool[] memory cardinalityChecks = testCardinality(configs);
    for (uint256 i = 0; i < prices.length; i++) {
      assertGt(prices[i], 0, "!Price Error ");
    }

    for (uint256 i = 0; i < cardinalityChecks.length; i ++) {
      assertEq(cardinalityChecks[i], true, "!Cardinality Error");
    }
  }

  function testCardinality(UniswapV3PriceOracle.AssetConfig[] memory configs) internal shouldRun(forChains(ARBITRUM_ONE)) returns (bool[] memory) {
    bool[] memory checks = new bool[](configs.length);
    for (uint256 i = 0; i < configs.length; i += 1) {
      (, , , uint16 observationCardinality, , , ) = IUniswapV3Pool(configs[i].poolAddress).slot0();
      checks[i] = observationCardinality >= 10;
    }

    return checks;
  }
}
