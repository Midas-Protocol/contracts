// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { IUniswapV2Pair } from "../../external/uniswap/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "../../external/uniswap/IUniswapV2Factory.sol";
import { IUniswapV3Factory } from "../../external/uniswap/IUniswapV3Factory.sol";
import { Quoter } from "../../external/uniswap/Quoter/Quoter.sol";
import { IUniswapV3Pool } from "../../external/uniswap/IUniswapV3Pool.sol";
import { ISwapRouter } from "../../external/uniswap/ISwapRouter.sol";
import { ERC4626Liquidator } from "../../liquidators/ERC4626Liquidator.sol";
import { BaseTest } from "../config/BaseTest.t.sol";
import { IERC4626 } from "../../compound/IERC4626.sol";

contract ERC4626LiquidatorTest is BaseTest {
  // a whale
  address holder = 0x3541Fda19b09769A938EB2A5f5154b01aE5b0869;

  IERC4626 erc4626Vault;
  address[] underlyingTokens;
  ERC4626Liquidator liquidator;
  IERC20Upgradeable daiToken;
  IERC20Upgradeable usdcToken;
  IERC20Upgradeable usdtToken;
  address usdcMarketAddress;
  address univ3SwapRouter;

  uint256 poolFee;

  Quoter quoter;

  function afterForkSetUp() internal override {
    if (block.chainid == ETHEREUM_MAINNET) {
      usdcToken = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
      daiToken = IERC20Upgradeable(0x6B175474E89094C44Da98b954EedeAC495271d0F);
      usdtToken = IERC20Upgradeable(0xdAC17F958D2ee523a2206206994597C13D831ec7);
      quoter = new Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
      erc4626Vault = IERC4626(0x97e6E0a40a3D02F12d1cEC30ebfbAE04e37C119E);
      underlyingTokens = asArray(address(usdcToken), address(daiToken), address(usdtToken)); // USDC, 6 decimals
      univ3SwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
      poolFee = 10;
    }
    liquidator = new ERC4626Liquidator();
  }

  function testRedeem() public fork(ETHEREUM_MAINNET) {
    // make sure we're testing with at least some tokens
    uint256 balance = erc4626Vault.balanceOf(holder);
    assertTrue(balance > 0);

    // impersonate the holder
    vm.prank(holder);

    // fund the liquidator so it can redeem the tokens
    erc4626Vault.transfer(address(liquidator), balance);

    // (IERC20Upgradeable _outputToken, uint24 fee, ISwapRouter swapRouter, address[] memory underlyingTokens, ) = abi
    //   .decode(strategyData, (IERC20Upgradeable, uint24, ISwapRouter, address[], Quoter));

    bytes memory data = abi.encode(address(usdcToken), poolFee, univ3SwapRouter, underlyingTokens, quoter);
    // redeem the underlying reward token
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      IERC20Upgradeable(address(erc4626Vault)),
      balance,
      data
    );
    uint256 usdcBalance = usdcToken.balanceOf(address(liquidator));

    assertEq(address(outputToken), address(usdcToken));
    assertEq(outputAmount, usdcBalance);
  }
}
