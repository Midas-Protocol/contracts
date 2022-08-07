// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { BalancerLpTokenPriceOracle } from "../../../oracles/default/BalancerLpTokenPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import "../../../external/balancer/IBalancerPool.sol";
import "../../../external/balancer/IBalancerVault.sol";

contract BalancerLpTokenPriceOracleTest is BaseTest {
  BalancerLpTokenPriceOracle private oracle;

  function setUp() public shouldRun(forChains(POLYGON_MAINNET)) {
    oracle = new BalancerLpTokenPriceOracle();
  }

  function testPriceBalancer() public shouldRun(forChains(POLYGON_MAINNET)) {
    IBalancerPool pool = IBalancerPool(0x82d7f08026e21c7713CfAd1071df7C8271B17Eae);

    bytes32 poolId = pool.getPoolId();

    IBalancerVault vault = IBalancerVault(address(pool.getVault()));
    (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangedBlock) = vault.getPoolTokens(poolId);

    emit log_uint(tokens.length);
    emit log_uint(tokens.length);

    address tokenA = address(tokens[0]);
    address tokenB = address(tokens[1]);

    emit log_address(tokenA);
    emit log_address(tokenB);

    uint256[] memory weights = pool.getNormalizedWeights();
    emit log_array(balances);
    emit log_array(weights);
    (uint256 fairResA, uint256 fairResB) = oracle.computeFairReserves(
      balances[0],
      balances[1],
      weights[0],
      weights[1],
      1e18,
      2e18
    );
    emit log_uint(fairResA);
    emit log_uint(fairResB);
    uint256 price = (fairResA * 1e18 + fairResB * 2e18) / pool.totalSupply();
    emit log_uint(price);
    // uint8 decimalsA = ERC20Upgradeable(tokenA).decimals();
    // uint8 decimalsB = ERC20Upgradeable(tokenB).decimals();

    uint256 price1 = oracle.price(address(0x82d7f08026e21c7713CfAd1071df7C8271B17Eae));
    emit log_uint(price);
    assertEq(price, price1);
  }
}
