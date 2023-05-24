// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { BalancerLpTokenLiquidator } from "../../liquidators/BalancerLpTokenLiquidator.sol";
import { BalancerSwapLiquidator } from "../../liquidators/BalancerSwapLiquidator.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import "../../external/balancer/IBalancerPool.sol";
import "../../external/balancer/IBalancerVault.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "../config/BaseTest.t.sol";

contract BalancerLpTokenLiquidatorTest is BaseTest {
  BalancerLpTokenLiquidator private lpTokenLiquidator;
  BalancerSwapLiquidator private swapLiquidator;

  function afterForkSetUp() internal override {
    lpTokenLiquidator = new BalancerLpTokenLiquidator();
    swapLiquidator = new BalancerSwapLiquidator();
  }

  function testRedeem(
    address whaleAddress,
    address lpTokenAddress,
    address outputTokenAddress
  ) internal {
    return testRedeem(lpTokenLiquidator, 1e18, whaleAddress, lpTokenAddress, outputTokenAddress);
  }

  function testRedeem(
    IRedemptionStrategy liquidator,
    uint256 amount,
    address whaleAddress,
    address lpTokenAddress,
    address outputTokenAddress
  ) internal {
    IERC20Upgradeable lpToken = IERC20Upgradeable(lpTokenAddress);
    IERC20Upgradeable outputToken = IERC20Upgradeable(outputTokenAddress);

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

  function testJbrlBrzLiquidatorRedeem() public fork(POLYGON_MAINNET) {
    address lpToken = 0xE22483774bd8611bE2Ad2F4194078DaC9159F4bA; // jBRL-BRZ stable
    address lpTokenWhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer V2
    address outputTokenAddress = 0xf2f77FE7b8e66571E0fca7104c4d670BF1C8d722; // jBRL

    testRedeem(lpTokenWhale, lpToken, outputTokenAddress);
  }

  function testBoostedAaveRedeem() public fork(POLYGON_MAINNET) {
    uint256 amount = 1e18;
    address lpToken = 0x48e6B98ef6329f8f0A30eBB8c7C960330d648085; // bb-am-USD
    address lpTokenWhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer V2
    address outputTokenAddress = 0xF93579002DBE8046c43FEfE86ec78b1112247BB8; // linear aaver usdc

    testRedeem(swapLiquidator, amount, lpTokenWhale, lpToken, outputTokenAddress);
  }

  function testLinearAaveRedeem() public fork(POLYGON_MAINNET) {
    uint256 amount = 1e18;
    address lpToken = 0xF93579002DBE8046c43FEfE86ec78b1112247BB8; // bb-am-USD
    address lpTokenWhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer V2
    address outputTokenAddress = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // USDC

    testRedeem(swapLiquidator, amount, lpTokenWhale, lpToken, outputTokenAddress);
  }
}
