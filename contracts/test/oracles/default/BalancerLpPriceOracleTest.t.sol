// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { BalancerLpTokenPriceOracle } from "../../../oracles/default/BalancerLpTokenPriceOracle.sol";
import { BalancerLpTokenPriceOracleNTokens } from "../../../oracles/default/BalancerLpTokenPriceOracleNTokens.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

import "../../../external/balancer/IBalancerPool.sol";
import "../../../external/balancer/IBalancerVault.sol";
import "../../../external/balancer/BNum.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract BalancerLpTokenPriceOracleTest is BaseTest, BNum {
  BalancerLpTokenPriceOracle oracle;
  BalancerLpTokenPriceOracleNTokens oracleNTokens;

  MasterPriceOracle mpo;

  address wbtc = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
  address weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

  address balWeth2080 = 0x3d468AB2329F296e1b9d8476Bb54Dd77D8c2320f;
  address wbtcWeth5050 = 0xCF354603A9AEbD2Ff9f33E1B04246d8Ea204ae95;
  address wmaticUsdcWethBal25252525 = 0x0297e37f1873D2DAb4487Aa67cD56B58E2F27875;
  address threeBrl333333 = 0x5A5E4Fa45Be4c9cb214cD4EC2f2eB7053F9b4F6D;

  address mimoPar8020 = 0x82d7f08026e21c7713CfAd1071df7C8271B17Eae;
  address mimoPar8020_c = 0x82d7f08026e21c7713CfAd1071df7C8271B17Eae;
  address mimo = 0xADAC33f543267c4D59a8c299cF804c303BC3e4aC;
  address par = 0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new BalancerLpTokenPriceOracle();
    oracleNTokens = new BalancerLpTokenPriceOracleNTokens();
    oracle.initialize(mpo);
    oracleNTokens.initialize(mpo);
  }

  // TODO: add test for mimo / par pair, when we deploy the MIMO DIA price oracle
  // See: https://github.com/Midas-Protocol/monorepo/issues/476
  function testPriceBalancer() public forkAtBlock(POLYGON_MAINNET, 33672239) {
    // uint256 lp_price = (pool.lp_price() * mpo.price(busd)) / 10**18;
    uint256 price = oracle.price(wbtcWeth5050);
    uint256 priceNTokens = oracleNTokens.price(wbtcWeth5050);

    // Based on this tx: https://polygonscan.com/tx/0xbd0a897bfef2e08bda92effcac2fedfb2a36e18d603ae46f4c294196f492ad8c
    // 65 USD$ worth of liquidity was removed for 0,012664670 wbtcWeth5050 tokens

    // (65,4 / 0,012664670) = 5.290,307 USD / wbtcWeth5050
    // 5.290,307 / 0,75 =  7.053,7426666667 wbtcWeth5050 / MATIC
    // 7.053,7426666 * 10**18 ~ 7e21
    assertEq(price, 6890799881956030175228);
    assertEq(price, priceNTokens);
  }

  function testPriceBalancerN() public forkAtBlock(POLYGON_MAINNET, 38399353) {
    IBalancerPool pool = IBalancerPool(wbtcWeth5050);
    bytes32 poolId = pool.getPoolId();
    IBalancerVault vault = IBalancerVault(address(pool.getVault()));
    (IERC20[] memory tokens, uint256[] memory balances, ) = vault.getPoolTokens(poolId);

    require(tokens.length == 2, "Oracle suitable only for Balancer Pools of 2 tokens");

    address tokenA = address(tokens[0]);
    address tokenB = address(tokens[1]);

    uint256[] memory weights = pool.getNormalizedWeights();

    uint256 pxA = mpo.price(tokenA);
    uint256 pxB = mpo.price(tokenB);

    uint8 decimalsA = ERC20Upgradeable(tokenA).decimals();
    uint8 decimalsB = ERC20Upgradeable(tokenB).decimals();

    if (decimalsA < 18) pxA = pxA * (10**(18 - uint256(decimalsA)));
    if (decimalsA > 18) pxA = pxA / (10**(uint256(decimalsA) - 18));
    if (decimalsB < 18) pxB = pxB * (10**(18 - uint256(decimalsB)));
    if (decimalsB > 18) pxB = pxB / (10**(uint256(decimalsB) - 18));

    uint256 fairResA;
    uint256 fairResB;

    uint256 r0 = bdiv(balances[0], balances[1]);

    emit log_named_uint("weights[0]", weights[0]);
    emit log_named_uint("pxB", pxB);
    emit log_named_uint("weights[1]", weights[1]);
    emit log_named_uint("pxA", pxA);

    uint256 r1 = bdiv(bmul(weights[0], pxB), bmul(weights[1], pxA));
    emit log_named_uint("r0", r0);
    emit log_named_uint("r1", r1);
    // fairResA = resA * (r1 / r0) ^ wB
    // fairResB = resB * (r0 / r1) ^ wA
    if (r0 > r1) {
      uint256 ratio = bdiv(r1, r0);
      fairResA = bmul(balances[0], bpow(ratio, weights[1]));
      fairResB = bdiv(balances[1], bpow(ratio, weights[0]));
    } else {
      uint256 ratio = bdiv(r0, r1);
      fairResA = bdiv(balances[0], bpow(ratio, weights[1]));
      fairResB = bmul(balances[1], bpow(ratio, weights[0]));
    }
  }

  function testPriceBalancerNTokens() public forkAtBlock(POLYGON_MAINNET, 38399353) {
    uint256 priceOracle = oracle.price(wbtcWeth5050);

    IBalancerPool pool = IBalancerPool(wmaticUsdcWethBal25252525);
    bytes32 poolId = pool.getPoolId();
    IBalancerVault vault = IBalancerVault(address(pool.getVault()));
    (IERC20[] memory tokens, uint256[] memory reserves, ) = vault.getPoolTokens(poolId);

    uint256 nTokens = tokens.length;
    uint256[] memory weights = pool.getNormalizedWeights();

    require(nTokens == weights.length, "nTokens != nWeights");

    uint256[] memory prices = new uint256[](nTokens);

    for (uint256 i = 0; i < nTokens; i++) {
      uint256 tokenPrice = mpo.price(address(tokens[i]));
      uint256 decimals = ERC20Upgradeable(address(tokens[i])).decimals();
      emit log_named_address("token", address(tokens[i]));
      emit log_named_uint("decimals", decimals);
      emit log_named_uint("tokenPrice", tokenPrice);
      emit log("");
      if (decimals < 18) {
        reserves[i] = reserves[i] * (10**(18 - decimals));
      } else if (decimals > 18) {
        reserves[i] = reserves[i] / (10**(decimals - 18));
      } else {
        reserves[i] = reserves[i];
      }
      prices[i] = tokenPrice;
    }
    for (uint256 i = 0; i < nTokens; i++) {
      emit log_named_address("token", address(tokens[i]));
      emit log_named_uint("prices[i]", prices[i]);
      emit log_named_uint("balances[i]", reserves[i]);
      emit log_named_uint("weights[i]", weights[i]);
      emit log("");
    }

    uint256[] memory fairReservesArray = new uint256[](nTokens);

    for (uint256 i = 0; i < reserves.length; i++) {
      emit log_named_address("token", address(tokens[i]));
      uint256[] memory r0array = new uint256[](reserves.length);
      uint256[] memory r1array = new uint256[](reserves.length);
      for (uint256 j = 0; j < reserves.length; j++) {
        if (i == j) {
          r0array[j] = 1;
          r1array[j] = 1;
        } else {
          r0array[j] = bdiv(reserves[i], reserves[j]);
          // bdiv(bmul(weights[0], pxB), bmul(weights[1], pxA));
          emit log("");
          emit log_named_uint("weights[i]", weights[i]);
          emit log_named_uint("prices[j]", prices[j]);
          emit log_named_uint("weights[j]", weights[j]);
          emit log_named_uint("prices[i]", prices[i]);
          emit log("");
          r1array[j] = bdiv(bmul(weights[i], prices[j]), bmul(weights[j], prices[i]));
          // r1array[j] = bmul(bdiv(weights[j], prices[j]), bdiv(prices[i], weights[i]));
        }
      }
      uint256 init = reserves[i];
      for (uint256 k = 0; k < r0array.length; k++) {
        uint256 r0 = r0array[k];
        uint256 r1 = r1array[k];
        emit log_named_uint("r0array[k]", r0);
        emit log_named_uint("r1array[k]", r1);

        if (r0 > r1) {
          uint256 ratio = bdiv(r1, r0);
          init = bmul(init, bpow(ratio, weights[k]));
        } else {
          uint256 ratio = bdiv(r0, r1);
          init = bmul(init, bpow(ratio, weights[k]));
        }
        emit log_named_uint("init", init);
      }
      fairReservesArray[i] = init;
      emit log("");
    }
    emit log("");

    uint256 fairResSum = 0;
    for (uint256 i = 0; i < fairReservesArray.length; i++) {
      emit log_named_address("token", address(tokens[i]));
      emit log_named_uint("fairReservesArray[i]", fairReservesArray[i]);
      fairResSum = fairResSum + fairReservesArray[i] * prices[i];
      emit log_named_uint("fairResSum", fairResSum);
      emit log("");
    }

    uint256 finalPrice = fairResSum / pool.totalSupply();
    emit log_named_uint("finalPrice", finalPrice);
    emit log_named_uint("priceOracle", priceOracle);

    // uint256 lp_price = (pool.lp_price() * mpo.price(busd)) / 10**18;
    // uint256 priceNTokens = oracleNTokens.price(wbtcWeth5050);

    // Based on this tx: https://polygonscan.com/tx/0xbd0a897bfef2e08bda92effcac2fedfb2a36e18d603ae46f4c294196f492ad8c
    // 65 USD$ worth of liquidity was removed for 0,012664670 wbtcWeth5050 tokens

    // (65,4 / 0,012664670) = 5.290,307 USD / wbtcWeth5050
    // 5.290,307 / 0,75 =  7.053,7426666667 wbtcWeth5050 / MATIC
    // 7.053,7426666 * 10**18 ~ 7e21
    // assertEq(price, 6890799881956030175228);
    // assertEq(price, priceNTokens);
  }
}
