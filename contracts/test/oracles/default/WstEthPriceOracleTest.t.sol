// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { WstEthPriceOracle } from "../../../oracles/default/WstEthPriceOracle.sol";

contract WstEthPriceOracleTest is BaseTest {
  // TODO: fix this after deploy of MPO
  WstEthPriceOracle private oracle;
  address stkBnb = 0xc2E9d07F66A89c44062459A47a0D2Dc038E4fb16;

  function afterForkSetUp() internal override {
    oracle = new WstEthPriceOracle();
    oracle.initialize();
  }

  function testStkBnbOraclePrice() public forkAtBlock(ETHEREUM_MAINNET, 17436402) {
    uint256 priceWstEth = oracle.price(stkBnb);

    assertGt(priceWstEth, 1e18);
    assertEq(priceWstEth, 1006482474298479702);
  }
}
