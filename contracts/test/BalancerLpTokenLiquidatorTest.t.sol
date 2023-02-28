// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BalancerLpTokenLiquidator } from "../liquidators/BalancerLpTokenLiquidator.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";
import "../external/balancer/IBalancerPool.sol";
import "../external/balancer/IBalancerVault.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract BalancerLpTokenLiquidatorTest is BaseTest {
  BalancerLpTokenLiquidator private liquidator;

  function afterForkSetUp() internal override {
    liquidator = new BalancerLpTokenLiquidator();
  }

  function testRedeem(
    address whaleAddress,
    address lpTokenAddress,
    address outputTokenAddress
  ) internal {
    IERC20Upgradeable lpToken = IERC20Upgradeable(lpTokenAddress);
    IERC20Upgradeable outputToken = IERC20Upgradeable(outputTokenAddress);

    uint256 amount = 1e18;
    vm.prank(whaleAddress);
    lpToken.transfer(address(liquidator), amount);

    uint256 balanceBefore = outputToken.balanceOf(address(liquidator));

    bytes memory data = abi.encode(address(outputToken));
    liquidator.redeem(lpToken, amount, data);

    uint256 balanceAfter = outputToken.balanceOf(address(liquidator));

    assertGt(balanceAfter - balanceBefore, 0, "!redeem lp token");
  }

  function testMimoParBalancerLpLiquidatorRedeem() public fork(POLYGON_MAINNET) {
    address lpToken = 0x82d7f08026e21c7713CfAd1071df7C8271B17Eae; //MIMO-PAR 8020
    address lpTokenWhale = 0xbB60ADbe38B4e6ab7fb0f9546C2C1b665B86af11;
    address outputTokenAddress = 0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128; // PAR

    testRedeem(lpTokenWhale, lpToken, outputTokenAddress);
  }

  function testWmaticStmaticLiquidatorRedeem() public fork(POLYGON_MAINNET) {
    address lpToken = 0x8159462d255C1D24915CB51ec361F700174cD994; // stMATIC-WMATIC stable
    address lpTokenWhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer V2
    address outputTokenAddress = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // WMATIC

    testRedeem(lpTokenWhale, lpToken, outputTokenAddress);
  }
}
