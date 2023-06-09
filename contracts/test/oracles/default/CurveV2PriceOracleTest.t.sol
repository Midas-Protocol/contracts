// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ICurveV2Pool } from "../../../external/curve/ICurveV2Pool.sol";
import { CurveV2PriceOracle } from "../../../oracles/default/CurveV2PriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { ICToken } from "../../../external/compound/ICToken.sol";

import { BaseTest } from "../../config/BaseTest.t.sol";

contract CurveV2PriceOracleTest is BaseTest {
  CurveV2PriceOracle oracle;
  address busd;
  address wbtc;

  address Bnbx = 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275;
  address epsBnbxBnb_pool = 0xFD4afeAc39DA03a05f61844095A75c4fB7D766DA;
  address epsBusdBtc_pool = 0xeF8A7e653F18CFD4b92a0f5b644393A4C635f19f;

  MasterPriceOracle mpo;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    busd = ap.getAddress("bUSD");
    wbtc = ap.getAddress("wBTCToken");

    address[] memory tokens = new address[](3);
    tokens[0] = Bnbx;
    tokens[1] = wbtc;
    tokens[2] = busd;

    address[] memory pools = new address[](3);
    pools[0] = epsBnbxBnb_pool;
    pools[1] = epsBusdBtc_pool;
    pools[2] = epsBusdBtc_pool;

    oracle = new CurveV2PriceOracle();
    oracle.initialize(tokens, pools);
    emit log_named_address("wbtc", wbtc);
  }

  function testCurveV2PriceOracleBNBxBNB() public fork(BSC_MAINNET) {
    vm.prank(address(mpo));
    uint256 bnbx_mpo_price = mpo.price(Bnbx);
    vm.startPrank(address(mpo));
    uint256 price = oracle.price(Bnbx);
    assertApproxEqRel(bnbx_mpo_price, price, 5e15); // 0.5%
    vm.stopPrank();
  }

  function testCurveV2PriceOracleWbtcBNB() public fork(BSC_MAINNET) {
    vm.prank(address(mpo));
    uint256 wbtc_mpo_price = mpo.price(wbtc);
    uint256 busd_mpo_price = mpo.price(busd);
    vm.startPrank(address(mpo));
    uint256 priceWbtc = oracle.price(wbtc);
    uint256 priceBusd = oracle.price(busd);
    assertApproxEqRel(wbtc_mpo_price, priceWbtc, 5e15); // 1%
    assertApproxEqRel(busd_mpo_price, priceBusd, 5e15); // 1%
    vm.stopPrank();
  }
}
