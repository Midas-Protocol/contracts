// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import "../liquidators/JarvisSynthereumLiquidator.sol";

contract JarvisSynthereumLiquidatorTest is BaseTest {
  JarvisSynthereumLiquidator private liquidator;
  address whale;
  ISynthereumLiquidityPool synthereumLiquiditiyPool;
  IERC20Upgradeable jBRLToken = IERC20Upgradeable(0x316622977073BBC3dF32E7d2A9B3c77596a0a603);
  IERC20Upgradeable bUSD = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

  function setUp() public {
    whale = 0xB57c5C22aA7b9Cd25D557f061Df61cBCe1898456;
    // TODO in addresses provider?
    synthereumLiquiditiyPool = ISynthereumLiquidityPool(0x0fD8170Dc284CD558325029f6AEc1538c7d99f49);
    uint64 expirationPeriod = 60 * 40; // 40 mins
    liquidator = new JarvisSynthereumLiquidator(synthereumLiquiditiyPool, expirationPeriod);
  }

  function testRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 whaleBalance = jBRLToken.balanceOf(whale);
    vm.prank(whale);
    jBRLToken.transfer(address(liquidator), whaleBalance);

    (uint256 redeemableAmount, ) = liquidator.pool().getRedeemTradeInfo(whaleBalance);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(jBRLToken, whaleBalance, "");

    // should be BUSD
    assertEq(address(outputToken), address(bUSD));
    assertEq(outputAmount, redeemableAmount);
  }

  function testEmergencyRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    ISynthereumLiquidityPool pool = liquidator.pool();
    address manager = pool.synthereumFinder().getImplementationAddress("Manager");
    vm.prank(manager);
    pool.emergencyShutdown();

    uint256 whaleBalance = jBRLToken.balanceOf(whale);
    vm.prank(whale);
    jBRLToken.transfer(address(liquidator), whaleBalance);

    (uint256 redeemableAmount, uint256 fee) = liquidator.pool().getRedeemTradeInfo(whaleBalance);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(jBRLToken, whaleBalance, "");

    // should be BUSD
    assertEq(address(outputToken), address(bUSD));
    assertEq(outputAmount, redeemableAmount + fee);
  }
}
