// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { BasePriceOracle } from "../../../oracles/BasePriceOracle.sol";

import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { BalancerLpStablePoolPriceOracle } from "../../../oracles/default/BalancerLpStablePoolPriceOracle.sol";
import { BalancerLpLinearPoolPriceOracle } from "../../../oracles/default/BalancerLpLinearPoolPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";
import { IBalancerStablePool } from "../../../external/balancer/IBalancerStablePool.sol";
import { IBalancerVault, UserBalanceOp } from "../../../external/balancer/IBalancerVault.sol";

contract BalancerLpStablePoolPriceOracleTest is BaseTest {
  BalancerLpStablePoolPriceOracle stableLpOracle;
  BalancerLpLinearPoolPriceOracle linearLpOracle;
  MasterPriceOracle mpo;

  address stMATIC_WMATIC_pool = 0x8159462d255C1D24915CB51ec361F700174cD994;
  address jBRL_BRZ_pool = 0xE22483774bd8611bE2Ad2F4194078DaC9159F4bA;
  address jEUR_agEUR_pool = 0xa48D164F6eB0EDC68bd03B56fa59E12F24499aD1;
  address boostedAavePool = 0x48e6B98ef6329f8f0A30eBB8c7C960330d648085;

  address linearAaveUsdtPool = 0xFf4ce5AAAb5a627bf82f4A571AB1cE94Aa365eA6;
  address linearAaveUsdcPool = 0xF93579002DBE8046c43FEfE86ec78b1112247BB8;
  address linearAaveDaiPool = 0x178E029173417b1F9C8bC16DCeC6f697bC323746;

  address MATICx_WMATIC_pool = 0xb20fC01D21A50d2C734C4a1262B4404d41fA7BF0;

  address stMATIC = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;
  address MATICx = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
  address agEUR = 0xE0B52e49357Fd4DAf2c15e02058DCE6BC0057db4;
  address jEUR = 0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c;
  address jBRL = 0xf2f77FE7b8e66571E0fca7104c4d670BF1C8d722;
  address BRZ = 0x491a4eB4f1FC3BfF8E1d2FC856a6A46663aD556f;
  address usdt = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
  address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    address wtoken = ap.getAddress("wtoken");

    address[][] memory stablePoolUnderlyings = new address[][](3);
    stablePoolUnderlyings[0] = asArray(stMATIC, wtoken);
    stablePoolUnderlyings[1] = asArray(jBRL, BRZ);
    stablePoolUnderlyings[2] = asArray(jEUR, agEUR);

    address[] memory stableLps = asArray(stMATIC_WMATIC_pool, jBRL_BRZ_pool, jEUR_agEUR_pool);
    address[] memory linearLps = asArray(linearAaveUsdtPool, linearAaveUsdcPool, linearAaveDaiPool);

    stableLpOracle = new BalancerLpStablePoolPriceOracle();
    stableLpOracle.initialize(stableLps, stablePoolUnderlyings);

    linearLpOracle = new BalancerLpLinearPoolPriceOracle();
    linearLpOracle.initialize(linearLps);
  }

  function getLpTokenPrice(address lpToken, IPriceOracle oracle) internal returns (uint256) {
    IPriceOracle[] memory oracles = new IPriceOracle[](1);
    oracles[0] = oracle;

    vm.prank(mpo.admin());
    mpo.add(asArray(lpToken), oracles);
    emit log("added the oracle");
    return mpo.price(lpToken);
  }

  function testReentrancyWmaticStmaticLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    // add the oracle to the mpo for that LP token
    {
      IPriceOracle[] memory oracles = new IPriceOracle[](1);
      oracles[0] = IPriceOracle(stableLpOracle);

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

  // Tests for ComposableStablePools
  function testWmaticStmaticLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    uint256 price = getLpTokenPrice(stMATIC_WMATIC_pool, stableLpOracle);
    assertTrue(price > 0);
    assertApproxEqAbs(price, mpo.price(stMATIC), 1e17);
  }

  function testJbrlBrzLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    uint256 price = getLpTokenPrice(jBRL_BRZ_pool, stableLpOracle);
    assertTrue(price > 0);
    assertApproxEqAbs(price, mpo.price(jBRL), 1e16);
  }

  function testBoostedAaveLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    // register the oracle
    vm.prank(stableLpOracle.owner());
    stableLpOracle.registerToken(boostedAavePool, asArray(usdt, usdc, dai));

    uint256 price = getLpTokenPrice(boostedAavePool, stableLpOracle);
    assertTrue(price > 0);
    assertApproxEqAbs(price, mpo.price(usdt), 1e16);
  }

  // Tests for LinearPools
  function testLinearAaveUsdtLpTokenOraclePrice() public fork(POLYGON_MAINNET) {
    uint256 price = getLpTokenPrice(linearAaveUsdtPool, linearLpOracle);

    assertTrue(price > 0);
    assertApproxEqAbs(price, mpo.price(usdt), 1e16);
  }

  // Tests @block number

  // tx: https://polygonscan.com/tx/0x098bc391015d6517850ffe54b268d65bf7886ca4ed4207d79a54ba11debcf445
  // - 2,995.9 for ~ 3,200 USD
  // 1 LP token = 1,068 USD
  function testForkedJeurAgEurLpTokenOraclePrice() public forkAtBlock(POLYGON_MAINNET, 40141540) {
    uint256 price = getLpTokenPrice(jEUR_agEUR_pool, stableLpOracle);

    assertTrue(price > 0);
    assertEq(price, 1015155060583030014); // 1,015e18 WMATIC * 1,05 USD/WMATIC =~ 1,066 USD
  }

  // https://polygonscan.com/tx/0xa061b632a95f2e0c81bacdb5a6d39991fb4e8436c52234373f9f736e2ad05e52
  // - 2,122 LP Tokens ~ 407.49 USD
  // 1 LP token = 0,1920 USD

  function testForkedJbrlBrzLpTokenOraclePrice() public forkAtBlock(POLYGON_MAINNET, 40120755) {
    uint256 price = getLpTokenPrice(jBRL_BRZ_pool, stableLpOracle);

    assertTrue(price > 0);
    assertEq(price, 179658854285035798); // 0,1796e18 WMATIC * 1,05 USD/WMATIC =~ 0,1888 USD
  }

  // https://polygonscan.com/tx/0x904e0a81c09b7340fab580b6f6210416e2aca9539c43d2a69fb72712b82a8a00
  // - 197.820 LP Tokens ~ $235.15 USD
  // 1 LP token = 1,188 USD

  function testForkedWmaticStMaticTokenOraclePrice() public forkAtBlock(POLYGON_MAINNET, 40304920) {
    uint256 price = getLpTokenPrice(stMATIC_WMATIC_pool, stableLpOracle);

    assertTrue(price > 0);
    assertEq(price, 1009290665332190911); // 1,0093 WMATIC * 1,18 USD/WMATIC =~ 1,1909 USD
  }

  function _reEntrancyTest(address[] memory lpTokens) internal {
    for (uint256 i = 0; i < lpTokens.length; i++) {
      IBalancerVault vault = IBalancerStablePool(lpTokens[i]).getVault();
      // raise the reentrancy flag for that vault
      vm.store(address(vault), bytes32(uint256(0)), bytes32(uint256(2)));
      vm.expectRevert(bytes("BAL#400"));
      vault.manageUserBalance(new UserBalanceOp[](0));
    }
  }

  // function testReentrancyErrorMessage() public fork(POLYGON_MAINNET) {
  //   // TODO configure it in the addresses provider after deployed (or just hardcode it here for polygon)
  //   stableLpOracle = BalancerLpStablePoolPriceOracle(ap.getAddress("BalancerLpStablePoolPriceOracle"));
  //   linearLpOracle = BalancerLpStablePoolPriceOracle(ap.getAddress("BalancerLpLinearPoolPriceOracle"));

  //   address[] memory stableLpTokens = stableLpOracle.getAllUnderlyings();
  //   address[] memory linearLpTokens = linearLpOracle.getAllUnderlyings();

  //   _reEntrancyTest(stableLpTokens);
  //   _reEntrancyTest(linearLpTokens);
  // }
}
