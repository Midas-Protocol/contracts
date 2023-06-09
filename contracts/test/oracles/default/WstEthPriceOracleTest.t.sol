// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { WstEthPriceOracle } from "../../../oracles/default/WstEthPriceOracle.sol";

contract WstEthPriceOracleTest is BaseTest {
  // TODO: fix this after deploy of MPO
  WstEthPriceOracle private oracle;
  address wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

  function afterForkSetUp() internal override {
    oracle = new WstEthPriceOracle();
    oracle.initialize();
  }

  function testWstEthOraclePrice() public forkAtBlock(ETHEREUM_MAINNET, 17436402) {
    uint256 priceWstEth = oracle.price(wstETH);

    assertGt(priceWstEth, 1e18);
    assertEq(priceWstEth, 1006482474298479702);
  }
}
