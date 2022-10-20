// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { BalancerLpTokenPriceOracle } from "../../../oracles/default/BalancerLpTokenPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import "../../../external/balancer/IBalancerPool.sol";
import "../../../external/balancer/IBalancerVault.sol";

contract BalancerLpTokenPriceOracleTest is BaseTest {
  BalancerLpTokenPriceOracle oracle;
  MasterPriceOracle mpo;

  address wbtc = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
  address weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
  address wbtcWeth5050 = 0xCF354603A9AEbD2Ff9f33E1B04246d8Ea204ae95;

  address mimoPar8020 = 0x82d7f08026e21c7713CfAd1071df7C8271B17Eae;
  address mimoPar8020_c = 0x82d7f08026e21c7713CfAd1071df7C8271B17Eae;
  address mimo = 0xADAC33f543267c4D59a8c299cF804c303BC3e4aC;
  address par = 0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128;

  function setUp() public {
    vm.createSelectFork("polygon", 33063212);
    setAddressProvider("polygon");
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function setUpBalancerOracle() public {
    vm.prank(mpo.admin());
    oracle.initialize(mpo);
  }

  // TODO: add test for mimo / par pair, when we deploy the MIMO DIA price oracle
  // See: https://github.com/Midas-Protocol/monorepo/issues/476
  function testPriceBalancer() public {
    vm.rollFork(33672239);

    oracle = new BalancerLpTokenPriceOracle();

    setUpBalancerOracle();

    // uint256 lp_price = (pool.lp_price() * mpo.price(busd)) / 10**18;
    uint256 price = oracle.price(wbtcWeth5050);

    // Based on this tx: https://polygonscan.com/tx/0xbd0a897bfef2e08bda92effcac2fedfb2a36e18d603ae46f4c294196f492ad8c
    // 65 USD$ worth of liquidity was removed for 0,012664670 wbtcWeth5050 tokens

    // (65,4 / 0,012664670) = 5.290,307 USD / wbtcWeth5050
    // 5.290,307 / 0,75 =  7.053,7426666667 wbtcWeth5050 / MATIC
    // 7.053,7426666 * 10**18 ~ 7e21
    assertEq(price, 6890799881956030175228);
  }
}
