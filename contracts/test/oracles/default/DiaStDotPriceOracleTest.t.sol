// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import { DiaStDotPriceOracle, DiaStDotOracle } from "../../../oracles/default/DiaStDotPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { ICToken } from "../../../external/compound/ICToken.sol";

contract DiaStDotPriceOracleTest is BaseTest {
  DiaStDotPriceOracle private oracle;
  MasterPriceOracle mpo;
  address stDot = 0xFA36Fe1dA08C89eC72Ea1F0143a35bFd5DAea108;
  ICToken stDot_c = ICToken(0x02bb982447B7Bb158952059F8cd2ab076D4B283B); // stDot cToken from pool 1
  address wstDot = 0x191cf2602Ca2e534c5Ccae7BCBF4C46a704bb949;
  address bUSD = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b;

  function setUp() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function setUpOracle() public {
    emit log_address(address(mpo));
    emit log_address(address(mpo.admin()));

    vm.prank(mpo.admin());
    oracle.initialize(
      MasterPriceOracle(ap.getAddress("MasterPriceOracle")),
      DiaStDotOracle(0xFEfe38321199e016c8d5e734A40eCCC0DBeC3711),
      stDot, // stDOT
      wstDot, // wstDOT
      bUSD // multiUSDC
    );
  }

  function testDiaStDotOraclePrice() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    vm.rollFork(1959099);

    oracle = new DiaStDotPriceOracle();

    setUpOracle();

    uint256 priceStDot = oracle.price(stDot);
    uint256 ulPriceStDot = oracle.getUnderlyingPrice(stDot_c);

    emit log_uint(priceStDot);
    emit log_uint(ulPriceStDot);
    uint256 priceWstDot = oracle.price(wstDot);

    assertEq(priceStDot, 13799919586975046579);
    assertEq(priceStDot, ulPriceStDot);

    assertEq(priceWstDot, 16554440075616894830);
  }
}
