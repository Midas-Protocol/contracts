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
  address MATICx_WMATIC_pool = 0xb20fC01D21A50d2C734C4a1262B4404d41fA7BF0;

  address stMATIC = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;
  address MATICx = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
  address jBRL = 0xf2f77FE7b8e66571E0fca7104c4d670BF1C8d722;
  address BRZ = 0x491a4eB4f1FC3BfF8E1d2FC856a6A46663aD556f;
  address usdt = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
  address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    address[] memory lpTokens = asArray(stMATIC_WMATIC_pool, jBRL_BRZ_pool, boostedAavePool);

    address[][] memory baseTokens = new address[][](3);
    baseTokens[0] = asArray(stMATIC);
    baseTokens[1] = asArray(jBRL, BRZ);
    baseTokens[2] = asArray(usdt, usdc, dai);

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
    // add the oracle to the mpo for that LP token
    {
      IPriceOracle[] memory oracles = new IPriceOracle[](1);
      oracles[0] = IPriceOracle(oracle);

      vm.prank(mpo.admin());
      mpo.add(asArray(stMATIC_WMATIC_pool), oracles);
    }

    address vault = address(IBalancerStablePool(stMATIC_WMATIC_pool).getVault());
    // raise the reentrancy flag for that vault
    vm.store(vault, bytes32(uint256(0)), bytes32(uint256(2)));
    // should revert with the specific message
    vm.expectRevert(bytes("Balancer vault view reentrancy"));
    mpo.price(stMATIC_WMATIC_pool);
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

  function testReentrancyErrorMessage() public fork(POLYGON_MAINNET) {
    // TODO configure it in the addresses provider after deployed (or just hardcode it here for polygon)
    oracle = BalancerLpStablePoolPriceOracle(ap.getAddress("BalancerLpStablePoolPriceOracle"));
    address[] memory lpTokens = oracle.getAllLpTokens();
    //address[] memory lpTokens = asArray(stMATIC_WMATIC_pool);
    for (uint256 i = 0; i < lpTokens.length; i++) {
      IBalancerVault vault = IBalancerStablePool(lpTokens[i]).getVault();
      // raise the reentrancy flag for that vault
      vm.store(address(vault), bytes32(uint256(0)), bytes32(uint256(2)));
      vm.expectRevert(bytes("BAL#400"));
      vault.manageUserBalance(new UserBalanceOp[](0));
    }
  }

  function testRegisterNewLpToken() public fork(POLYGON_MAINNET) {
    vm.prank(oracle.owner());

    uint256 lenghtBefore = oracle.getAllLpTokens().length;
    oracle.registerLpToken(MATICx_WMATIC_pool, asArray(MATICx));
    assertTrue(oracle.getAllLpTokens().length == lenghtBefore + 1);

    uint256 price = getLpTokenPrice(MATICx_WMATIC_pool);
    assertTrue(price > 0);
    assertApproxEqAbs(price, mpo.price(MATICx), 1e17);
  }
}
