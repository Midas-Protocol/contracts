// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { UniswapV3PriceOracle } from "../../../oracles/default/UniswapV3PriceOracle.sol";
import { IUniswapV3Pool } from "../../../external/uniswap/IUniswapV3Pool.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";

contract UniswapV3PriceOracleTest is BaseTest {
  UniswapV3PriceOracle oracle;
  MasterPriceOracle mpo;
  address wtoken;
  address stable;

  function afterForkSetUp() internal override {
    // Not using the address provider yet -- config just added
    // TODO: use ap when deployment is done
    stable = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC
    wtoken = ap.getAddress("wtoken"); // WETH
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new UniswapV3PriceOracle();

    vm.prank(mpo.admin());
    oracle.initialize(wtoken, stable);
  }

  function testArbitrumAssets() public forkAtBlock(ARBITRUM_ONE, 55624326) {
    address[] memory underlyings = new address[](7);
    UniswapV3PriceOracle.AssetConfig[] memory configs = new UniswapV3PriceOracle.AssetConfig[](7);

    underlyings[0] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX (18 decimals)
    underlyings[1] = 0x6C2C06790b3E3E3c38e12Ee22F8183b37a13EE55; // DPX (18 decimals)
    underlyings[2] = 0x539bdE0d7Dbd336b79148AA742883198BBF60342; // MAGIC (18 decimals)
    underlyings[3] = 0xD74f5255D557944cf7Dd0E45FF521520002D5748; // USDs (18 decimals)
    underlyings[4] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT (6 decimals)
    underlyings[5] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX (18 decimals)
    underlyings[6] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // WBTC (8 decimals)

    // GMX-ETH
    configs[0] = UniswapV3PriceOracle.AssetConfig(
      0x80A9ae39310abf666A87C743d6ebBD0E8C42158E,
      10 minutes,
      UniswapV3PriceOracle.FeedBaseCurrency.NATIVE
    );
    // DPX-ETH
    configs[1] = UniswapV3PriceOracle.AssetConfig(
      0xb52781C275431bD48d290a4318e338FE0dF89eb9,
      10 minutes,
      UniswapV3PriceOracle.FeedBaseCurrency.NATIVE
    );
    // MAGIC-ETH
    configs[2] = UniswapV3PriceOracle.AssetConfig(
      0x7e7FB3CCEcA5F2ac952eDF221fd2a9f62E411980,
      10 minutes,
      UniswapV3PriceOracle.FeedBaseCurrency.NATIVE
    );
    // USDs-USDC
    configs[3] = UniswapV3PriceOracle.AssetConfig(
      0x50450351517117Cb58189edBa6bbaD6284D45902,
      10 minutes,
      UniswapV3PriceOracle.FeedBaseCurrency.USD
    );
    // USDT-USDC
    configs[4] = UniswapV3PriceOracle.AssetConfig(
      0x13398E27a21Be1218b6900cbEDF677571df42A48,
      10 minutes,
      UniswapV3PriceOracle.FeedBaseCurrency.USD
    );
    // GMX-USDC
    configs[5] = UniswapV3PriceOracle.AssetConfig(
      0xBed2589feFAE17d62A8a4FdAC92fa5895cAe90d2,
      10 minutes,
      UniswapV3PriceOracle.FeedBaseCurrency.USD
    );
    // WBTC-USDC
    configs[6] = UniswapV3PriceOracle.AssetConfig(
      0xA62aD78825E3a55A77823F00Fe0050F567c1e4EE,
      10 minutes,
      UniswapV3PriceOracle.FeedBaseCurrency.USD
    );

    uint256[] memory expPrices = new uint256[](7);
    expPrices[0] = 32303551248749710; // (32303551248749710 / 1e18) * 1600 = 51.7 (26/01/2022)
    expPrices[1] = 186352358731969434;
    expPrices[2] = 817348875792654;
    expPrices[3] = 616728830044297; // (616728830044297 / 1e18) * 1600 = 0,985 (26/01/2022)
    expPrices[4] = 617962412544658;
    expPrices[5] = 32303551248749710;
    expPrices[6] = 14272222356770933950; //  (14272222356770933950 / 1e18) * 1600 = 22,835 (26/01/2022)

    emit log_named_uint("USDC PRICE", mpo.price(stable));
    uint256[] memory prices = getPriceFeed(underlyings, configs);
    for (uint256 i = 0; i < prices.length; i++) {
      assertEq(prices[i], expPrices[i], "!Price Error");
    }

    bool[] memory cardinalityChecks = getCardinality(configs);
    for (uint256 i = 0; i < cardinalityChecks.length; i++) {
      assertEq(cardinalityChecks[i], true, "!Cardinality Error");
    }
  }

  function getPriceFeed(address[] memory underlyings, UniswapV3PriceOracle.AssetConfig[] memory configs)
    internal
    returns (uint256[] memory price)
  {
    vm.prank(oracle.owner());
    oracle.setPoolFeeds(underlyings, configs);
    vm.roll(1);

    price = new uint256[](underlyings.length);
    for (uint256 i = 0; i < underlyings.length; i++) {
      vm.prank(address(mpo));
      price[i] = oracle.price(underlyings[i]);
    }
    return price;
  }

  function getCardinality(UniswapV3PriceOracle.AssetConfig[] memory configs) internal view returns (bool[] memory) {
    bool[] memory checks = new bool[](configs.length);
    for (uint256 i = 0; i < configs.length; i += 1) {
      (, , , , uint16 observationCardinalityNext, , ) = IUniswapV3Pool(configs[i].poolAddress).slot0();
      checks[i] = observationCardinalityNext >= 10;
    }

    return checks;
  }
}
