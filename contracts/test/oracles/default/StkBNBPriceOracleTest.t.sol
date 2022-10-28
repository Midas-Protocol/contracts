// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import { StkBNBPriceOracle } from "../../../oracles/default/StkBNBPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { ICToken } from "../../../external/compound/ICToken.sol";

contract StkBNBPriceOracleTest is BaseTest {
  StkBNBPriceOracle private oracle;
  MasterPriceOracle mpo;
  address stkBnb = 0xc2E9d07F66A89c44062459A47a0D2Dc038E4fb16;

  function setUp() public forkAtBlock(BSC_MAINNET, 21952914) {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new StkBNBPriceOracle();
    vm.prank(mpo.admin());
    oracle.initialize();
  }

  function testStkBnbOraclePrice() public {
    uint256 priceStkBnb = oracle.price(stkBnb);

    assertGt(priceStkBnb, 1e18);
    assertEq(priceStkBnb, 1006482474298479702);
  }
}
