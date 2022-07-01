// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import { AnkrBNBcPriceOracle, AnkrOracle } from "../../../oracles/default/AnkrBNBcPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

contract AnkrBNBcPriceOracleTest is BaseTest {
  AnkrBNBcPriceOracle private oracle;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    oracle = new AnkrBNBcPriceOracle(
      AnkrOracle(0xB1aD00B8BB49FB3534120b43f1FEACeAf584AE06),
      MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
      0xE85aFCcDaFBE7F2B096f268e31ccE3da8dA2990A,
      ap.getAddress("bUSD")
    );
  }

  function testPrice() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 price = oracle.price(0xE85aFCcDaFBE7F2B096f268e31ccE3da8dA2990A);
    assertEq(price, 1019848384416702590);
  }
}
