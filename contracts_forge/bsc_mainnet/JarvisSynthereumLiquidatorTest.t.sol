// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../config/BaseTest.t.sol";
import "../../contracts/liquidators/JarvisSynthereumLiquidator.sol";

contract JarvisSynthereumLiquidatorTest is BscMainnetBaseTest {
  JarvisSynthereumLiquidator private liquidator;
  ChainConfig private chainConfig;
  address whale = 0xB57c5C22aA7b9Cd25D557f061Df61cBCe1898456;

  function setUp() public override {
    super.setUp();
    chainConfig = chainConfigs[block.chainid];
    uint64 expirationPeriod = 60 * 40; // 40 mins
    liquidator = new JarvisSynthereumLiquidator(chainConfig.synthereumLiquiditiyPool, expirationPeriod);
  }

  function testRedeemToken() public {
    IERC20Upgradeable jBRLToken = chainConfig.coins[1];
    uint256 whaleBalance = jBRLToken.balanceOf(whale);
    vm.prank(whale);
    jBRLToken.transfer(address(liquidator), whaleBalance);

    (uint256 redeemableAmount, ) = liquidator.pool().getRedeemTradeInfo(whaleBalance);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(jBRLToken, whaleBalance, "");

    // should be BUSD
    assertEq(address(outputToken), address(chainConfig.coins[0]));
    assertEq(outputAmount, redeemableAmount);
  }

    function testEmergencyRedeemToken() public {
      ISynthereumLiquidityPool pool = liquidator.pool();
      address manager = pool.synthereumFinder().getImplementationAddress('Manager');
      vm.prank(manager);
      pool.emergencyShutdown();

      IERC20Upgradeable jBRLToken = chainConfig.coins[1];
      uint256 whaleBalance = jBRLToken.balanceOf(whale);
      vm.prank(whale);
      jBRLToken.transfer(address(liquidator), whaleBalance);

      (uint256 redeemableAmount, uint256 fee) = liquidator.pool().getRedeemTradeInfo(whaleBalance);
      (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(jBRLToken, whaleBalance, "");

      // should be BUSD
      assertEq(address(outputToken), address(chainConfig.coins[0]));
      assertEq(outputAmount, redeemableAmount + fee);
    }
}
