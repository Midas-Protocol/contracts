// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { UniswapLpTokenPriceOracle } from "../../../oracles/default/UniswapLpTokenPriceOracle.sol";
import { SolidlyLpTokenPriceOracle } from "../../../oracles/default/SolidlyLpTokenPriceOracle.sol";
import { UniswapLikeLpTokenPriceOracle } from "../../../oracles/default/UniswapLikeLpTokenPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";

contract UniswapLpTokenBaseTest is BaseTest {
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

  function testBombBtcLpTokenOraclePrice() public fork(BSC_MAINNET) {
    address lpToken = 0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6; // Lp BOMB-BTCB

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
  }

  function testBnbXBnbSolidly() public fork(BSC_MAINNET) {
    address lpToken = 0x6c83E45fE3Be4A9c12BB28cB5BA4cD210455fb55; // Lp BNBx/WBNB (volatile AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    uint256 priceBnbX = mpo.price(0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275);
    uint256 priceWbnb = mpo.price(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    assertTrue(price > 0);
    assertApproxEqAbs(priceBnbX + priceWbnb, price, 1e16);
  }

  function testBusdUsdtSolidly() public fork(BSC_MAINNET) {
    address lpToken = 0x618f9Eb0E1a698409621f4F487B563529f003643; // Lp USDT/USDC (stable AMM)

    uint256 price = getLpPrice(lpToken, getSolidlyLpTokenPriceOracle());
    uint256 priceUsdc = mpo.price(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    uint256 priceUsdt = mpo.price(0x55d398326f99059fF775485246999027B3197955);

    assertTrue(price > 0);
    assertApproxEqAbs(priceUsdc + priceUsdt, price, 1e17);
  }

  function testGlmrUsdcLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0xb929914B89584b4081C7966AC6287636F7EfD053; // Lp GLMR-USDC

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
  }

  function testGlmrGlintLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0x99588867e817023162F4d4829995299054a5fC57; // Lp GLMR-GLINT

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
  }

  function testWGlmrWethLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0x8577273FB3B72306F3A59E26ab77116f5D428DAa; // Lp GLMR-GLINT

    uint256 price = getLpPrice(lpToken, getUniswapLpTokenPriceOracle());
    assertTrue(price > 0);
  }
}
