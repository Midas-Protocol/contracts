// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { GammaPoolPriceOracle } from "../../../oracles/default/GammaPoolPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { LiquidityAmounts } from "../../../external/uniswap/LiquidityAmounts.sol";
import { IUniswapV3Pool } from "../../../external/uniswap/IUniswapV3Pool.sol";

import { IHypervisor } from "../../../external/gamma/IHypervisor.sol";

contract GammaPoolPriceOracleTest is BaseTest {
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

  function testPriceGammaPolygonNow() public fork(POLYGON_MAINNET) {
    {
      uint256 withdrawAmount = 1e18;
      address DAI_GNS_QS_GAMMA_VAULT = 0x7aE7FB44c92B4d41abB6E28494f46a2EB3c2a690; // QS aDAI-GNS (Narrow)
      address DAI_GNS_QS_GAMMA_WHALE = 0x20ec0d06F447d550fC6edee42121bc8C1817b97D; // QS Masterchef

      vm.prank(address(mpo));
      uint256 price_DAI_GNS = oracle.price(DAI_GNS_QS_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(DAI_GNS_QS_GAMMA_WHALE, DAI_GNS_QS_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_DAI_GNS, expectedPrice, 1e16, "!aDAI-GNS price");
    }

    {
      uint256 withdrawAmount = 1e6;
      address DAI_USDT_QS_GAMMA_VAULT = 0x45A3A657b834699f5cC902e796c547F826703b79;
      address DAI_USDT_QS_WHALE = 0x20ec0d06F447d550fC6edee42121bc8C1817b97D; // QS Masterchef

      vm.prank(address(mpo));
      uint256 price_DAI_USDT = oracle.price(DAI_USDT_QS_GAMMA_VAULT) / (1e18 / withdrawAmount);

      uint256 expectedPrice = priceAtWithdraw(DAI_USDT_QS_WHALE, DAI_USDT_QS_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_DAI_USDT, expectedPrice, 1e16, "!aDAI-USDT price");
    }

    {
      uint256 withdrawAmount = 1e6;
      address WETH_USDT_QS_GAMMA_VAULT = 0x5928f9f61902b139e1c40cBa59077516734ff09f; // QS aWETH-USDT (Narrow)
      address WETH_USDT_QS_WHALE = 0x20ec0d06F447d550fC6edee42121bc8C1817b97D; // QS Masterchef

      vm.prank(address(mpo));
      uint256 price_WETH_USDT = oracle.price(WETH_USDT_QS_GAMMA_VAULT) / (1e18 / withdrawAmount);

      uint256 expectedPrice = priceAtWithdraw(WETH_USDT_QS_WHALE, WETH_USDT_QS_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_WETH_USDT, expectedPrice, 5e16, "!aWETH-USDT price");
    }
  }

  function testPriceGammaBscNow() public fork(BSC_MAINNET) {
    uint256 withdrawAmount = 1e18;
    {
      address USDT_WBNB_THENA_GAMMA_VAULT = 0x921C7aC35D9a528440B75137066adb1547289555; // Wide
      address USDT_WBNB_THENA_WHALE = 0x04008Bf76d2BC193858101d932135e09FBfF4779; // thena gauge for aUSDT-WBNB

      vm.prank(address(mpo));
      uint256 price_USDT_WBNB = oracle.price(USDT_WBNB_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(USDT_WBNB_THENA_WHALE, USDT_WBNB_THENA_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_USDT_WBNB, expectedPrice, 1e16, "!aUSDT-WBNB price");
    }

    {
      address USDT_USDC_THENA_GAMMA_VAULT = 0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2;
      address USDT_USDC_THENA_WHALE = 0x1011530830c914970CAa96a52B9DA1C709Ea48fb; // thena gauge

      vm.prank(address(mpo));
      uint256 price_USDT_USDC = oracle.price(USDT_USDC_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(USDT_USDC_THENA_WHALE, USDT_USDC_THENA_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_USDT_USDC, expectedPrice, 1e16, "!USDT_USDC price");
    }

    {
      address WBTC_WBNB_THENA_GAMMA_VAULT = 0xBd2383816Bab04E46b69801CCa7e92D34aB94D3F; // Wide
      address WBTC_WBNB_THENA_WHALE = 0xb75942D49e7F455C47DebBDCA81DF67244fe7d40; // thena gauge

      vm.prank(address(mpo));
      uint256 price_WBTC_WBNB = oracle.price(WBTC_WBNB_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(WBTC_WBNB_THENA_WHALE, WBTC_WBNB_THENA_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_WBTC_WBNB, expectedPrice, 1e16, "!WBTC_WBNB price");
    }
  }

  function priceAtWithdraw(
    address whale,
    address vaultAddress,
    uint256 withdrawAmount
  ) internal returns (uint256) {
    address emptyAddress = address(900202020);
    IHypervisor vault = IHypervisor(vaultAddress);
    ERC20Upgradeable token0 = ERC20Upgradeable(vault.token0());
    ERC20Upgradeable token1 = ERC20Upgradeable(vault.token1());

    uint256 balance0Before = token0.balanceOf(emptyAddress);
    uint256 balance1Before = token1.balanceOf(emptyAddress);

    uint256[4] memory minAmounts;
    vm.prank(whale);
    vault.withdraw(withdrawAmount, emptyAddress, whale, minAmounts);

    uint256 balance0After = token0.balanceOf(emptyAddress);
    uint256 balance1After = token1.balanceOf(emptyAddress);

    uint256 price0 = mpo.price(address(token0));
    uint256 price1 = mpo.price(address(token1));

    uint256 balance0Diff = (balance0After - balance0Before) * 10**(18 - uint256(token0.decimals()));
    uint256 balance1Diff = (balance1After - balance1Before) * 10**(18 - uint256(token1.decimals()));

    return (balance0Diff * price0 + balance1Diff * price1) / 1e18;
  }

  function testForkedPriceGammaBsc() public forkAtBlock(BSC_MAINNET, 27513712) {
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

  function testForkedPriceGammaPolygon() public forkAtBlock(POLYGON_MAINNET, 41974636) {
    address WETH_USDT_QS_GAMMA_VAULT = 0x5928f9f61902b139e1c40cBa59077516734ff09f;

    vm.prank(address(mpo));
    uint256 price_WETH_USDT = oracle.price(WETH_USDT_QS_GAMMA_VAULT);

    // https://polygonscan.com/tx/0x7e2f52f179edeac5d737f0b1980e7ef822d021749439362ba17e52456cc6025b
    // $6.05 WTH + $5.01 USDT For 0.000000000005738166 aWETH-USDT
    // 11.06  / 0.000000000005738166 = 1,925e12 $/aUSDT-aUSDC
    // 1975910114418720837175563648030 -> 1,975e12  * 1.00$ = 1,975e12$ (26/04/2023)
    assertEq(price_WETH_USDT, 1975910114418720837175563648030);
  }
}
