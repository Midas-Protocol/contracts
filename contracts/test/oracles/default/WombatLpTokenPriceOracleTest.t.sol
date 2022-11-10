// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import { WombatLpTokenPriceOracle } from "../../../oracles/default/WombatLpTokenPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

contract WombatLpTokenPriceOracleTest is BaseTest {
  WombatLpTokenPriceOracle private oracle;

  function afterForkSetUp() internal override {
    oracle = new WombatLpTokenPriceOracle();
  }

  function testPrice() public forkAtBlock(BSC_MAINNET, 22933276) {
    // price for Wombat Wrapped BNB asset
    vm.prank(ap.getAddress("MasterPriceOracle"));
    uint256 price = oracle.price(0x74f019A5C4eD2C2950Ce16FaD7Af838549092c5b);
    assertEq(price, 1e18);
  }
}
