// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { BalancerLpStablePoolPriceOracle } from "../../../oracles/default/BalancerLpStablePoolPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";
import { IBalancerStablePool } from "../../../external/balancer/IBalancerStablePool.sol";
import { IBalancerVault, UserBalanceOp } from "../../../external/balancer/IBalancerVault.sol";

contract BalancerLpStablePoolPriceOracleTest is BaseTest {
  BalancerLpStablePoolPriceOracle oracle;
  MasterPriceOracle mpo;

  address stMATIC_WMATIC_pool = 0x8159462d255C1D24915CB51ec361F700174cD994;
  address jBRL_BRZ_pool = 0xE22483774bd8611bE2Ad2F4194078DaC9159F4bA;
  address boostedAavePool = 0x48e6B98ef6329f8f0A30eBB8c7C960330d648085;

  address stMATIC = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;
  address jBRL = 0xf2f77FE7b8e66571E0fca7104c4d670BF1C8d722;
  address usdt = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    address[] memory lpTokens = asArray(stMATIC_WMATIC_pool, jBRL_BRZ_pool, boostedAavePool);

    address[] memory baseTokens = asArray(stMATIC, jBRL, usdt);

    oracle = new BalancerLpStablePoolPriceOracle();
    oracle.initialize(lpTokens, baseTokens);
  }

  function getLpTokenPrice(address lpToken) internal returns (uint256) {
    IPriceOracle[] memory oracles = new IPriceOracle[](1);
    oracles[0] = IPriceOracle(oracle);

    vm.prank(mpo.admin());
    mpo.add(asArray(lpToken), oracles);
    emit log("added the oracle");
    return mpo.price(lpToken);
  }

  function testReentrancyWmaticStmaticLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    IBalancerVault ibVault = IBalancerStablePool(stMATIC_WMATIC_pool).getVault();
    address vault = address(ibVault);
    // raise the reentrancy flag for that vault
    vm.store(vault, bytes32(uint256(0)), bytes32(uint256(2)));

    uint256 price = getLpTokenPrice(stMATIC_WMATIC_pool);
    assertEq(price, 0, "should return 0 when a reentrancy is detected");
  }

  function testWmaticStmaticLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    uint256 price = getLpTokenPrice(stMATIC_WMATIC_pool);
    assertTrue(price > 0);
    assertApproxEqAbs(price, mpo.price(stMATIC), 1e16);
  }

  function testJbrlBrzLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    uint256 price = getLpTokenPrice(jBRL_BRZ_pool);
    assertTrue(price > 0);
    assertApproxEqAbs(price, mpo.price(jBRL), 1e16);
  }

  function testBoostedAaveLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    uint256 price = getLpTokenPrice(boostedAavePool);
    assertTrue(price > 0);
    assertApproxEqAbs(price, mpo.price(usdt), 1e16);
  }
}
