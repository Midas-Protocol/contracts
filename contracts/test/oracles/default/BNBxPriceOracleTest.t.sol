// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import { BNBxPriceOracle } from "../../../oracles/default/BNBxPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { ICToken } from "../../../external/compound/ICToken.sol";

contract BNBxPriceOracleTest is BaseTest {
  BNBxPriceOracle private oracle;
  MasterPriceOracle mpo;
  address BNBx = 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275;

  function setUp() public {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    if (block.chainid == BSC_MAINNET) {
      setUpOracle();
    }
  }

  function setUpOracle() public {
    vm.rollFork(22332594);

    oracle = new BNBxPriceOracle();
    vm.prank(mpo.admin());
    oracle.initialize();
  }

  function testBnbXOraclePrice() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 priceBnbX = oracle.price(BNBx);

    assertGt(priceBnbX, 1e18);
    assertEq(priceBnbX, 1041708576933034575);
  }
}
