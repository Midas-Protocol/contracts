// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";
import { GammaLpTokenLiquidator, GammaLpTokenWrapper } from "../../liquidators/GammaLpTokenLiquidator.sol";
import { IHypervisor } from "../../external/gamma/IHypervisor.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract GammaLpTokenLiquidatorTest is BaseTest {
  GammaLpTokenLiquidator public liquidator;
  address algebraSwapRouter = 0x327Dd3208f0bCF590A66110aCB6e5e6941A4EfA0;
  address uniProxy = 0x6B3d98406779DDca311E6C43553773207b506Fa6;
  address wbnb;

  function afterForkSetUp() internal override {
    liquidator = new GammaLpTokenLiquidator();
    wbnb = ap.getAddress("wtoken");
  }

  function testGammaLpTokenLiquidator() public fork(BSC_MAINNET) {
    uint256 withdrawAmount = 1e18;
    address USDT_WBNB_THENA_GAMMA_VAULT = 0x921C7aC35D9a528440B75137066adb1547289555; // Wide
    address USDT_WBNB_THENA_WHALE = 0x04008Bf76d2BC193858101d932135e09FBfF4779; // thena gauge for aUSDT-WBNB

    IHypervisor vault = IHypervisor(USDT_WBNB_THENA_GAMMA_VAULT);
    vm.prank(USDT_WBNB_THENA_WHALE);
    vault.transfer(address(liquidator), withdrawAmount);

    address outputTokenAddress = ap.getAddress("wtoken"); // WBNB
    bytes memory strategyData = abi.encode(outputTokenAddress, algebraSwapRouter);
    (, uint256 outputAmount) = liquidator.redeem(vault, withdrawAmount, strategyData);

    emit log_named_uint("wbnb redeemed", outputAmount);
    assertGt(outputAmount, 0, "!failed to withdraw and swap");
  }

  function testGammaLpTokenWrapper() public fork(BSC_MAINNET) {
    address USDT_WBNB_THENA_GAMMA_VAULT = 0x921C7aC35D9a528440B75137066adb1547289555; // Wide
    IHypervisor vault = IHypervisor(USDT_WBNB_THENA_GAMMA_VAULT);
    address wbnbWhale = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
    address usdtAddress = 0x55d398326f99059fF775485246999027B3197955;

    GammaLpTokenWrapper wrapper = new GammaLpTokenWrapper();
    vm.prank(wbnbWhale);
    IERC20Upgradeable(wbnb).transfer(address(wrapper), 1e18);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = wrapper.redeem(
      IERC20Upgradeable(wbnb),
      1e18,
      abi.encode(algebraSwapRouter, uniProxy, vault)
    );

    emit log_named_uint("lp tokens minted", outputAmount);

    assertGt(outputToken.balanceOf(address(wrapper)), 0, "!wrapped");
    assertEq(IERC20Upgradeable(wbnb).balanceOf(address(wrapper)), 0, "!unused wbnb");
    assertEq(IERC20Upgradeable(usdtAddress).balanceOf(address(wrapper)), 0, "!unused usdt");
  }
}
