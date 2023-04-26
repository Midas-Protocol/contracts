// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { GammaPoolPriceOracle } from "../../../oracles/default/GammaPoolPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { LiquidityAmounts } from "../../../external/uniswap/LiquidityAmounts.sol";
import { TickMath } from "../../../external/uniswap/TickMath.sol";
import { IUniswapV3Pool } from "../../../external/uniswap/IUniswapV3Pool.sol";

import { IHypervisor } from "../../../external/gamma/IHypervisor.sol";

contract GelatoGUniPriceOracleTest is BaseTest {
  GammaPoolPriceOracle private oracle;
  MasterPriceOracle mpo;
  address wtoken;
  address stable;

  function afterForkSetUp() internal override {
    stable = ap.getAddress("stableToken");
    wtoken = ap.getAddress("wtoken"); // WETH
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new GammaPoolPriceOracle();
    vm.prank(mpo.admin());
    oracle.initialize(wtoken);
  }

  function testPriceGammaBscNow() public fork(BSC_MAINNET) {
    {
      address USDT_WBNB_THENA_GAMMA_VAULT = 0x921C7aC35D9a528440B75137066adb1547289555; // Wide
      address USDT_WBNB_THENA_WHALE = 0x04008Bf76d2BC193858101d932135e09FBfF4779; // thena gauge for aUSDT-WBNB

      vm.prank(address(mpo));
      uint256 price_USDT_WBNB = oracle.price(USDT_WBNB_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(USDT_WBNB_THENA_WHALE, USDT_WBNB_THENA_GAMMA_VAULT);
      assertApproxEqAbs(price_USDT_WBNB, expectedPrice, 1e16, "!aUSDT-WBNB price");
    }

    {
      address USDT_USDC_THENA_GAMMA_VAULT = 0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2;
      address USDT_USDC_THENA_WHALE = 0x1011530830c914970CAa96a52B9DA1C709Ea48fb; // thena gauge

      vm.prank(address(mpo));
      uint256 price_USDT_USDC = oracle.price(USDT_USDC_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(USDT_USDC_THENA_WHALE, USDT_USDC_THENA_GAMMA_VAULT);
      assertApproxEqAbs(price_USDT_USDC, expectedPrice, 1e16, "!USDT_USDC price");
    }

    {
      address WBTC_WBNB_THENA_GAMMA_VAULT = 0xBd2383816Bab04E46b69801CCa7e92D34aB94D3F; // Wide
      address WBTC_WBNB_THENA_WHALE = 0xb75942D49e7F455C47DebBDCA81DF67244fe7d40; // thena gauge

      vm.prank(address(mpo));
      uint256 price_WBTC_WBNB = oracle.price(WBTC_WBNB_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(WBTC_WBNB_THENA_WHALE, WBTC_WBNB_THENA_GAMMA_VAULT);
      assertApproxEqAbs(price_WBTC_WBNB, expectedPrice, 1e16, "!WBTC_WBNB price");
    }
  }

  function priceAtWithdraw(address whale, address vaultAddress) internal returns (uint256) {
    address emptyAddress = address(900202020);
    IHypervisor vault = IHypervisor(vaultAddress);
    address token0 = vault.token0();
    address token1 = vault.token1();

    uint256 balance0Before = ERC20Upgradeable(token0).balanceOf(emptyAddress);
    uint256 balance1Before = ERC20Upgradeable(token1).balanceOf(emptyAddress);

    uint256[4] memory minAmounts;
    vm.prank(whale);
    vault.withdraw(1e18, emptyAddress, whale, minAmounts);

    uint256 balance0After = ERC20Upgradeable(token0).balanceOf(emptyAddress);
    uint256 balance1After = ERC20Upgradeable(token1).balanceOf(emptyAddress);

    uint256 price0 = mpo.price(token0);
    uint256 price1 = mpo.price(token1);

    uint256 balance0Diff = balance0After - balance0Before;
    uint256 balance1Diff = balance1After - balance1Before;

    // TODO tokens decimals
    return (balance0Diff * price0 + balance1Diff * price1) / 1e18;
  }

  function testFrokedPriceGammaBsc() public forkAtBlock(BSC_MAINNET, 27513712) {
    address USDT_USDC_THENA_GAMMA_VAULT = 0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2;
    address USDT_WBNB_THENA_GAMMA_VAULT = 0x3ec1FFd5dc29190588608Ae9Fd4f93750e84CDA2; // Wide
    address WBTC_WBNB_THENA_GAMMA_VAULT = 0xBd2383816Bab04E46b69801CCa7e92D34aB94D3F; // Wide

    vm.prank(address(mpo));
    uint256 price_USDT_USDC = oracle.price(USDT_USDC_THENA_GAMMA_VAULT);

    vm.prank(address(mpo));
    uint256 price_USDT_WBNB = oracle.price(USDT_WBNB_THENA_GAMMA_VAULT);

    vm.prank(address(mpo));
    uint256 price_WBTC_WBNB = oracle.price(WBTC_WBNB_THENA_GAMMA_VAULT);

    // https://bscscan.com/tx/0x02c9c0942e17876fed8e18189bc2169de32c3c8269a2029a29a913c60b9ed59a
    // $0.92 USDT + $1.09 USDC For 2.016366914 aUSDT-aUSDC
    // (0.92 + 1.09) / 2.016366914 = 0.997 $/aUSDT-aUSDC
    // 3064998281441246 -> 0,00306 * 326$ = 0,998$ (20/04/2023)
    assertEq(price_USDT_USDC, 3064989914431908);

    // https://bscscan.com/tx/0x96ded191ae0f8942d21d77aad96502fbe4a9c4d67e7aafaf2080aeb8ca997994
    // $0.54 USDT + $2.92 WBNB For 0.0025 aUSDT-WBNB
    // (0.54 + 2.92) / 0.0025 = 1,384 $/aUSDT-WBNB
    // 4243236477963371140 -> 4,243 * 326$ = 1,383$ (20/04/2023)
    assertEq(price_USDT_WBNB, 4243236477963371140);

    // https://bscscan.com/tx/0x3cced3b18b7189b23f53e305a0bc824e508ccf4862d01f3b40066ecd6bdceb00
    // $2.88 BTCB + $2.61 WBNB For 0.017072595190748917 aBTCB-WBNB
    // (2.88 + 2.61) / 0.017072595190748917 = 321.56 $/aBTCB-WBNB
    // 987759909770553133 -> 0,98 * 326$ = 318,28$ (20/04/2023)
    assertEq(price_WBTC_WBNB, 987759884020563446);
  }
}
