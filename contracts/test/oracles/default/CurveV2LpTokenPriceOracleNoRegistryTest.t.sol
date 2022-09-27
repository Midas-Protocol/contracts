// 0x4544d21EB5B368b3f8F98DcBd03f28aC0Cf6A0CA// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import { ICurveV2Pool } from "../../../external/curve/ICurveV2Pool.sol";
import "../../../oracles/default/CurveV2LpTokenPriceOracleNoRegistry.sol";
import "../../config/BaseTest.t.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

contract CurveLpTokenPriceOracleNoRegistryTest is BaseTest {
  CurveV2LpTokenPriceOracleNoRegistry oracle;
  address epsJCHFBUSD_lp = 0x5887cEa5e2bb7dD36F0C06Da47A8Df918c289A29;
  address epsJCHFBUSD_pool = 0xBcA6E25937B0F7E0FD8130076b6B218F595E32e2;
  ICToken epsJCHFBUSD_c = ICToken(0x1F0452D6a8bb9EAbC53Fa6809Fa0a060Dd531267);
  MasterPriceOracle mpo;

  function setUp() public {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function setUpCurveOracle(address lpToken, address pool) public {
    address[] memory lpTokens = new address[](1);
    lpTokens[0] = lpToken;
    address[] memory pools = new address[](1);
    pools[0] = pool;

    vm.prank(mpo.admin());
    oracle.initialize(lpTokens, pools);
  }

  function testCurveLpTokenPriceOracleNoRegistry() public shouldRun(forChains(BSC_MAINNET)) {
    vm.rollFork(21675481);

    oracle = new CurveV2LpTokenPriceOracleNoRegistry();

    setUpCurveOracle(epsJCHFBUSD_lp, epsJCHFBUSD_pool);

    ICurveV2Pool pool = ICurveV2Pool(epsJCHFBUSD_pool);
    uint256 lp_price = pool.lp_price();
    uint256 price = oracle.price(epsJCHFBUSD_lp);
    uint256 ulPrice = oracle.getUnderlyingPrice(epsJCHFBUSD_c);
    assertEq(price, ulPrice);
    assertEq(price, lp_price);
    assertEq(price, 2012556774399901376);
  }
}
