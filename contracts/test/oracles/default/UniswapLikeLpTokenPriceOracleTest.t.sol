// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { IPair } from "../../../external/solidly/IPair.sol";
import { IUniswapV2Pair } from "../../../external/uniswap/IUniswapV2Pair.sol";
import { UniswapLpTokenPriceOracle } from "../../../oracles/default/UniswapLpTokenPriceOracle.sol";
import { SolidlyLpTokenPriceOracle } from "../../../oracles/default/SolidlyLpTokenPriceOracle.sol";
import { UniswapLikeLpTokenPriceOracle } from "../../../oracles/default/UniswapLikeLpTokenPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";

contract UniswapLikeLpTokenPriceOracleTest is BaseTest {
  UniswapLikeLpTokenPriceOracle uniswapLpTokenPriceOracle;
  MasterPriceOracle mpo;
  address wtoken;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function getSolidlyLpTokenPriceOracle() internal returns (UniswapLikeLpTokenPriceOracle) {
    return new SolidlyLpTokenPriceOracle(wtoken);
  }

  function getUniswapLpTokenPriceOracle() internal returns (UniswapLikeLpTokenPriceOracle) {
    return new UniswapLpTokenPriceOracle(wtoken);
  }

  function getLpPrice(address lpToken, UniswapLikeLpTokenPriceOracle oracle) internal returns (uint256) {
    if (address(mpo.oracles(lpToken)) == address(0)) {
      address[] memory underlyings = new address[](1);
      IPriceOracle[] memory oracles = new IPriceOracle[](1);

      underlyings[0] = lpToken;
      oracles[0] = IPriceOracle(oracle);

      vm.prank(mpo.admin());
      mpo.add(underlyings, oracles);
      emit log("added the oracle");
    } else {
      emit log("found the oracle");
    }
    return mpo.price(lpToken);
  }

  function verifyLpPrice(
    address lpToken,
    uint256 price,
    uint256 tolerance
  ) internal {
    uint256 priceToken0 = mpo.price(IPair(lpToken).token0());
    uint256 priceToken1 = mpo.price(IPair(lpToken).token1());
    assertApproxEqAbs(2 * sqrt(priceToken0) * sqrt(priceToken1), price, tolerance);
  }

  function testBusdWbnbUniswap() public fork(BSC_MAINNET) {
    address lpToken = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16; // Lp WBNB-BUSD

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e17);
  }

  function testBnbXBnbSolidly() public fork(BSC_MAINNET) {
    address lpToken = 0x6c83E45fE3Be4A9c12BB28cB5BA4cD210455fb55; // Lp BNBx/WBNB (volatile AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e14);
  }

  function testUsdtUsdcSolidly() public fork(BSC_MAINNET) {
    address lpToken = 0x618f9Eb0E1a698409621f4F487B563529f003643; // Lp USDT/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e14);
  }

  function testBusdWbnbSolidly() public fork(BSC_MAINNET) {
    address lpToken = 0x483653bcF3a10d9a1c334CE16a19471a614F4385; // Lp USDT/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e14);
  }

  function testGlmrUsdcLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0xb929914B89584b4081C7966AC6287636F7EfD053; // Lp GLMR-USDC

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e16);
  }

  function testGlmrGlintLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0x99588867e817023162F4d4829995299054a5fC57; // Lp GLMR-GLINT

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e16);
  }

  function testWGlmrWethLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0x8577273FB3B72306F3A59E26ab77116f5D428DAa; // Lp GLMR-GLINT

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
    verifyLpPrice(lpToken, price, 1e16);
  }
}
