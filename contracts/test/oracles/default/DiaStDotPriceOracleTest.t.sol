// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { DiaStDotPriceOracle, DiaStDotOracle } from "../../../oracles/default/DiaStDotPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { ICToken } from "../../../external/compound/ICToken.sol";

contract DiaStDotPriceOracleTest is BaseTest {
  DiaStDotPriceOracle private oracle;
  MasterPriceOracle mpo;
  address stDot = 0xFA36Fe1dA08C89eC72Ea1F0143a35bFd5DAea108;
  ICToken stDot_c = ICToken(0x02bb982447B7Bb158952059F8cd2ab076D4B283B); // stDot cToken from pool 1
  address wstDot = 0x191cf2602Ca2e534c5Ccae7BCBF4C46a704bb949;
  address multiUsdc = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b;

  function setUp() public forkAtBlock(MOONBEAM_MAINNET, 1959099) {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    setUpOracle();
  }

  function setUpOracle() public {
    oracle = new DiaStDotPriceOracle();
    vm.startPrank(mpo.admin());
    oracle.initialize(mpo, DiaStDotOracle(0xFEfe38321199e016c8d5e734A40eCCC0DBeC3711), multiUsdc);
    oracle.reinitialize();
    vm.stopPrank();
  }

  function testDiaStDotOraclePrice() public {
    uint256 priceStDot = oracle.price(stDot);
    uint256 priceWstDot = oracle.price(wstDot);

    // (13799919586975046579 / 1e18) * 0,45 = 6,209
    // at Block Number 1959099, price of GLMR ~ 0,45 USD, price of DOT ~ 6,36 USD
    // stDot trades at a discount

    assertEq(priceStDot, 13799919586975046579);
    assertEq(priceWstDot, 16554440075616894830);
  }
}
