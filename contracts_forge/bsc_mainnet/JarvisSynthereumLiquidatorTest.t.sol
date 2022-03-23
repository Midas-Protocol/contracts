// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../config/BaseTest.t.sol";
import "../../contracts/liquidators/JarvisSynthereumLiquidator.sol";

contract JarvisSynthereumLiquidatorTest is BscMainnetBaseTest {
  JarvisSynthereumLiquidator private liquidator;
  ChainConfig private chainConfig;

  function setUp() override public {
    super.setUp();
    chainConfig = chainConfigs[block.chainid];
    uint64 expirationPeriod = 60 * 40; // 40 mins
    liquidator = new JarvisSynthereumLiquidator(chainConfig.synthereumLiquiditiyPool, expirationPeriod);
  }

  function testRedeemToken() public {
    IERC20Upgradeable jBRLToken = chainConfig.coins[1];
    address whale = 0xB57c5C22aA7b9Cd25D557f061Df61cBCe1898456;
    uint256 whaleBalance = jBRLToken.balanceOf(whale);
    vm.prank(whale);
    jBRLToken.transfer(address(liquidator), whaleBalance);

    (uint256 redeemableAmount, ) = liquidator.pool().getRedeemTradeInfo(whaleBalance);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(jBRLToken, whaleBalance, "");

    // should be BUSD
    assertEq(address(outputToken), address(chainConfig.coins[0]));
    assertEq(outputAmount, redeemableAmount);
  }

//  function testEmergencyRedeemToken() public {
//    address manager = liquidator.pool().synthereumFinder().getImplementationAddress('Manager'); //0x4d616e61676572
//    // manager = 0x43a98e5C4A7F3B7f11080fc9D58b0B8A80cA954e
//    vm.prank(manager);
//    // [FAIL. Reason: Caller must be the Synthereum manager]
//    liquidator.pool().emergencyShutdown();
//  }
}
