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

  function testPriceGammaBsc1() public forkAtBlock(BSC_MAINNET, 27513712) {
    // address USDT_USDC_THENA_GAMMA_VAULT = 0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2;
    address USDT_WBNB_THENA_GAMMA_VAULT = 0x921C7aC35D9a528440B75137066adb1547289555; // Wide
    address WBTC_WBNB_THENA_GAMMA_VAULT = 0xBd2383816Bab04E46b69801CCa7e92D34aB94D3F; // Wide

    // vm.prank(address(mpo));
    // uint256 price_USDT_USDC = oracle.price(USDT_USDC_THENA_GAMMA_VAULT);

    vm.prank(address(mpo));
    uint256 price_USDT_WBNB = oracle.price(USDT_WBNB_THENA_GAMMA_VAULT);

    vm.prank(address(mpo));
    uint256 price_WBTC_WBNB = oracle.price(WBTC_WBNB_THENA_GAMMA_VAULT);

    // https://bscscan.com/tx/0x02c9c0942e17876fed8e18189bc2169de32c3c8269a2029a29a913c60b9ed59a
    // $0.92 USDT + $1.09 USDC For 2.016366914 aUSDT-aUSDC
    // (0.92 + 1.09) / 2.016366914 = 0.997 $/aUSDT-aUSDC
    // 3064998281441246 -> 0,00306 * 326$ = 0,998$ (20/04/2023)
    // assertEq(price_USDT_USDC, 3064998281441246); // 0,00306e18 => 0,00306 * 326$ = 0,998$ (20/04/2023)

    // https://bscscan.com/tx/0x96ded191ae0f8942d21d77aad96502fbe4a9c4d67e7aafaf2080aeb8ca997994
    // $0.54 USDT + $2.92 WBNB For 0.0025 aUSDT-WBNB
    // (0.54 + 2.92) / 0.0025 = 1,384 $/aUSDT-WBNB
    // 4243249301361717720 -> 4,24 * 326$ = 1383$ (20/04/2023)
    assertEq(price_USDT_WBNB, 4243249301361717720); // 0,97375e18 => 0,97375 * 326$ = 317,5$ (20/04/2023)

    // https://bscscan.com/tx/0x3cced3b18b7189b23f53e305a0bc824e508ccf4862d01f3b40066ecd6bdceb00
    // $2.88 BTCB + $2.61 WBNB For 0.017072595190748917 aBTCB-WBNB
    // (2.88 + 2.61) / 0.017072595190748917 = 321.56 $/aBTCB-WBNB
    // 987759909770553133 -> 0,98 * 326$ = 318,28$ (20/04/2023)
    assertEq(price_WBTC_WBNB, 987759909770553133);
  }

  //   function testPriceGammaBsc() public fork(BSC_MAINNET) {
  //     address USDT_USDC_THENA_GAMMA_VAULT = 0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2;
  //     // address USDT_WBNB_THENA_GAMMA_VAULT = 0x3ec1FFd5dc29190588608Ae9Fd4f93750e84CDA2;
  //     // address WBTC_WBNB_THENA_GAMMA_VAULT = 0xBd2383816Bab04E46b69801CCa7e92D34aB94D3F;

  //     IHypervisor pool = IHypervisor(USDT_USDC_THENA_GAMMA_VAULT);

  //     ERC20Upgradeable token0 = ERC20Upgradeable(pool.token0());
  //     ERC20Upgradeable token1 = ERC20Upgradeable(pool.token1());

  //     // Get underlying token prices
  //     uint256 p0 = mpo.price(address(token0)) * 10**uint256(18 - token0.decimals());
  //     uint256 p1 = mpo.price(address(token1)) * 10**uint256(18 - token1.decimals());

  //     emit log_named_uint("p0", p0);
  //     emit log_named_uint("p1", p1);

  //     uint160 sqrtPriceX96 = toUint160(
  //       sqrt((p0 * (10**token0.decimals()) * (1 << 96)) / (p1 * (10**token0.decimals()))) << 48
  //     );
  //     emit log_named_uint("sqrtPriceX96", sqrtPriceX96);

  //     (uint256 base0, uint256 base1) = _getPositionAtPrice(
  //       pool.baseLower(),
  //       pool.baseUpper(),
  //       sqrtPriceX96,
  //       USDT_USDC_THENA_GAMMA_VAULT,
  //       IUniswapV3Pool(pool.pool())
  //     );
  //     (uint256 limit0, uint256 limit1) = _getPositionAtPrice(
  //       pool.limitLower(),
  //       pool.limitUpper(),
  //       sqrtPriceX96,
  //       USDT_USDC_THENA_GAMMA_VAULT,
  //       IUniswapV3Pool(pool.pool())
  //     );
  //     emit log_named_uint("base0", base0);
  //     emit log_named_uint("base1", base1);
  //     emit log_named_uint("limit0", limit0);
  //     emit log_named_uint("limit1", limit1);
  //   }

  //   function _getPositionAtPrice(
  //     int24 tickLower,
  //     int24 tickUpper,
  //     uint160 sqrtRatioX96,
  //     address token,
  //     IUniswapV3Pool pool
  //   ) public returns (uint256 amount0, uint256 amount1) {
  //     emit log_named_int("tickLower", tickLower);
  //     emit log_named_int("tickUpper", tickUpper);
  //     emit log_named_address("pool", address(pool));
  //     (uint128 positionLiquidity, uint128 tokensOwed0, uint128 tokensOwed1) = _position(
  //       pool,
  //       token,
  //       tickLower,
  //       tickUpper
  //     );

  //     (amount0, amount1) = _amountsForLiquidityAtPrice(tickLower, tickUpper, positionLiquidity, sqrtRatioX96);
  //     amount0 = amount0 + uint256(tokensOwed0);
  //     amount1 = amount1 + uint256(tokensOwed1);
  //   }

  //   function _amountsForLiquidityAtPrice(
  //     int24 tickLower,
  //     int24 tickUpper,
  //     uint128 liquidity,
  //     uint160 sqrtRatioX96
  //   ) internal pure returns (uint256, uint256) {
  //     return
  //       LiquidityAmounts.getAmountsForLiquidity(
  //         sqrtRatioX96,
  //         TickMath.getSqrtRatioAtTick(tickLower),
  //         TickMath.getSqrtRatioAtTick(tickUpper),
  //         liquidity
  //       );
  //   }

  //   function _position(
  //     IUniswapV3Pool pool,
  //     address token,
  //     int24 lowerTick,
  //     int24 upperTick
  //   )
  //     internal
  //     returns (
  //       uint128 liquidity,
  //       uint128 tokensOwed0,
  //       uint128 tokensOwed1
  //     )
  //   {
  //     bytes32 positionKey;
  //     assembly {
  //       positionKey := or(shl(24, or(shl(24, token), and(lowerTick, 0xFFFFFF))), and(upperTick, 0xFFFFFF))
  //     }

  //     emit log_named_bytes32("positionKey", positionKey);
  //     (liquidity, , , tokensOwed0, tokensOwed1) = pool.positions(positionKey);
  //   }

  //   /**
  //    * @dev Converts uint256 to uint160.
  //    */
  //   function toUint160(uint256 x) internal pure returns (uint160 z) {
  //     require((z = uint160(x)) == x, "Overflow when converting uint256 into uint160.");
  //   }
}
