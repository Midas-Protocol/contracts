// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { GammaPoolPriceOracle } from "../../../oracles/default/GammaPoolPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

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

  function testPriceGammaBsc() public forkAtBlock(BSC_MAINNET, 27513712) {
    address USDT_USDC_THENA_GAMMA_VAULT = 0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2;
    address USDT_WBNB_THENA_GAMMA_VAULT = 0x3ec1FFd5dc29190588608Ae9Fd4f93750e84CDA2;
    address WBTC_WBNB_THENA_GAMMA_VAULT = 0xBd2383816Bab04E46b69801CCa7e92D34aB94D3F;

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
    assertEq(price_USDT_USDC, 3064998281441246); // 0,00306e18 => 0,00306 * 326$ = 0,998$ (20/04/2023)

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
}
