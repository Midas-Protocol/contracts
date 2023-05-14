// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";
import { GammaLpTokenLiquidator } from "../../liquidators/GammaLpTokenLiquidator.sol";
import { IHypervisor } from "../../external/gamma/IHypervisor.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract GammaLpTokenLiquidatorTest is BaseTest {
  GammaLpTokenLiquidator public liquidator;
  address algebraSwapRouter = 0x327Dd3208f0bCF590A66110aCB6e5e6941A4EfA0;

  function afterForkSetUp() internal override {
    liquidator = new GammaLpTokenLiquidator();
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
    (, uint256 outputAmount) = liquidator.redeem(
      vault,
      withdrawAmount,
      strategyData
    );

    emit log_named_uint("wbnb redeemed", outputAmount);
    assertGt(outputAmount, 0, "!failed to withdraw and swap");
  }
}