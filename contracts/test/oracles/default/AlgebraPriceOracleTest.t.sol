// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { AlgebraPriceOracle } from "../../../oracles/default/AlgebraPriceOracle.sol";
import { ConcentratedLiquidityBasePriceOracle } from "../../../oracles/default/ConcentratedLiquidityBasePriceOracle.sol";
import { IAlgebraPool } from "../../../external/algebra/IAlgebraPool.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";

contract AlgebraPriceOracleTest is BaseTest {
  AlgebraPriceOracle oracle;
  MasterPriceOracle mpo;
  address wtoken;
  address stable;

  function afterForkSetUp() internal override {
    // Not using the address provider yet -- config just added
    // TODO: use ap when deployment is done

    stable = ap.getAddress("stableToken");
    wtoken = ap.getAddress("wtoken"); // WETH
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new AlgebraPriceOracle();

    vm.prank(mpo.admin());
    oracle.initialize(wtoken, asArray(stable));
  }

  function testPolygonAssets() public forkAtBlock(POLYGON_MAINNET, 40783999) {
    address maticX = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
    address wbtc = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;

    address[] memory underlyings = new address[](2);
    ConcentratedLiquidityBasePriceOracle.AssetConfig[]
      memory configs = new ConcentratedLiquidityBasePriceOracle.AssetConfig[](2);

    underlyings[0] = maticX; // MaticX (18 decimals)
    underlyings[1] = wbtc; // WBTC (8 decimals)

    // MaticX-Wmatic
    configs[0] = ConcentratedLiquidityBasePriceOracle.AssetConfig(
      0x05BFE97Bf794a4DB69d3059091F064eA0a5E538E,
      10 minutes,
      wtoken
    );
    // WBTC-USDC
    configs[1] = ConcentratedLiquidityBasePriceOracle.AssetConfig(
      0xA5CD8351Cbf30B531C7b11B0D9d3Ff38eA2E280f,
      10 minutes,
      stable
    );

    uint256[] memory expPrices = new uint256[](2);
    expPrices[0] = 1055376214918982029; //  1,152$ / 1.09 =  1.056985 MATIC   (26/03/2023)
    expPrices[1] = mpo.price(wbtc);

    uint256[] memory prices = getPriceFeed(underlyings, configs);

    assertEq(prices[0], expPrices[0], "!Price Error");
    assertApproxEqRel(prices[1], expPrices[1], 1e17, "!Price Error");
  }

  function getPriceFeed(address[] memory underlyings, ConcentratedLiquidityBasePriceOracle.AssetConfig[] memory configs)
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

  function testSetUnsupportedBaseToken() public forkAtBlock(POLYGON_MAINNET, 0, 5244 / 1, 098) {
    address usdt = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address ixt = 0xE06Bd4F5aAc8D0aA337D13eC88dB6defC6eAEefE;

    address[] memory underlyings = new address[](1);
    ConcentratedLiquidityBasePriceOracle.AssetConfig[]
      memory configs = new ConcentratedLiquidityBasePriceOracle.AssetConfig[](1);

    underlyings[0] = ixt;

    // USDT/IXT
    configs[0] = ConcentratedLiquidityBasePriceOracle.AssetConfig(
      0xD6e486c197606559946384AE2624367d750A160f,
      10 minutes,
      usdt
    );
    // revert if underlying is not supported
    vm.startPrank(oracle.owner());
    vm.expectRevert(bytes("Base token must be supported"));
    oracle.setPoolFeeds(underlyings, configs);

    // add it successfully when suported
    oracle._setSupportedBaseTokens(asArray(usdt, stable));
    oracle.setPoolFeeds(underlyings, configs);
    vm.stopPrank();

    // check prices
    vm.prank(address(mpo));
    uint256 price = oracle.price(ixt);
    assertEq(price, 480815305168365489, "!Price Error"); // 0.5244 USDT / 1.098$ = 0.477 MATIC (26/03/2023)
  }
}
