// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BasePriceOracle } from "../../../oracles/BasePriceOracle.sol";
import { BalancerRateProviderOracle } from "../../../oracles/default/BalancerRateProviderOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";
import { IBalancerStablePool } from "../../../external/balancer/IBalancerStablePool.sol";
import { IBalancerVault, UserBalanceOp } from "../../../external/balancer/IBalancerVault.sol";

contract BalancerRateProviderOracleTest is BaseTest {
  BalancerRateProviderOracle oracle;
  MasterPriceOracle mpo;
  uint256 wtokenPrice;

  // base tokens
  address wtoken;
  address weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

  // Underlyings
  address stMATIC = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;
  address MATICx = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
  address csMATIC = 0xFcBB00dF1d663eeE58123946A30AB2138bF9eb2A;
  address wstETH = 0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD;

  // Rate Providers
  address csMATICRateProvider = 0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051;
  address stMATICRateProvider = 0xdEd6C522d803E35f65318a9a4d7333a22d582199;
  address MATICxRateProvider = 0xeE652bbF72689AA59F0B8F981c9c90e2A8Af8d8f;
  address wstETHRateProvider = 0x8c1944E305c590FaDAf0aDe4f737f5f95a4971B6;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    wtoken = ap.getAddress("wtoken");
    wtokenPrice = mpo.price(wtoken);
    address[] memory underlyings = asArray(stMATIC, MATICx, csMATIC);
    address[] memory baseTokens = asArray(wtoken, wtoken, wtoken);
    address[] memory rateProviders = asArray(stMATICRateProvider, MATICxRateProvider, csMATICRateProvider);

    oracle = new BalancerRateProviderOracle();
    oracle.initialize(rateProviders, baseTokens, underlyings);
  }

  function getTokenPrice(address token) internal returns (uint256) {
    BasePriceOracle[] memory oracles = new BasePriceOracle[](1);
    oracles[0] = BasePriceOracle(oracle);

    vm.prank(mpo.admin());
    mpo.add(asArray(token), oracles);
    emit log("added the oracle");
    return mpo.price(token);
  }

  function testStmaticTokenOraclePrice() public fork(POLYGON_MAINNET) {
    uint256 priceFromMpo = mpo.price(stMATIC);
    uint256 priceFromRateProviderOracle = getTokenPrice(stMATIC);
    assertApproxEqRel(priceFromMpo, priceFromRateProviderOracle, 1e16, "!diff > 1%");

    // Must be close but higher than to the price for WTOKEN
    assertTrue(priceFromRateProviderOracle > wtokenPrice);
    assertApproxEqRel(mpo.price(wtoken), priceFromRateProviderOracle, 2e17, "!diff > 20%");
  }

  function testMaticXTokenOraclePrice() public fork(POLYGON_MAINNET) {
    uint256 priceFromMpo = mpo.price(MATICx);
    uint256 priceFromRateProviderOracle = getTokenPrice(MATICx);
    assertApproxEqRel(priceFromMpo, priceFromRateProviderOracle, 1e16, "!diff > 1%");
    // Must be close but higher than to the price for WTOKEN
    assertTrue(priceFromRateProviderOracle > wtokenPrice);
    assertApproxEqRel(mpo.price(wtoken), priceFromRateProviderOracle, 2e17, "!diff > 20%");
  }

  function testCsMaticTokenOraclePrice() public fork(POLYGON_MAINNET) {
    // We don't have yet a price feed for csMATIC currently live
    // uint256 priceFromMpo = mpo.price(csMATIC);
    uint256 priceFromRateProviderOracle = getTokenPrice(csMATIC);
    // assertApproxEqRel(priceFromMpo, priceFromRateProviderOracle, 1e16, "!diff > 1%");
    // Must be close but higher than to the price for WTOKEN
    assertTrue(priceFromRateProviderOracle > wtokenPrice);
    assertApproxEqRel(mpo.price(wtoken), priceFromRateProviderOracle, 2e17, "!diff > 20%");
  }

  function testRegisterNewToken() public fork(POLYGON_MAINNET) {
    vm.prank(oracle.owner());

    uint256 lenghtBefore = oracle.getAllUnderlyings().length;
    oracle.registerToken(wstETHRateProvider, weth, wstETH);
    assertTrue(oracle.getAllUnderlyings().length == lenghtBefore + 1);

    uint256 price = getTokenPrice(wstETH);
    // Must be close but higher than to the price for WETH
    assertTrue(price > mpo.price(weth));
    assertApproxEqRel(mpo.price(weth), price, 2e17, "!diff > 20%");
  }
}
