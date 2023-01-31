// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { UniswapLpTokenPriceOracle } from "../../../oracles/default/UniswapLpTokenPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";

contract UniswapLpTokenBaseTest is BaseTest {
  UniswapLpTokenPriceOracle uniswapLpTokenPriceOracle;
  MasterPriceOracle mpo;
  address wtoken;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function getLpTokenPrice(address lpToken) internal returns (uint256) {
    if (address(mpo.oracles(lpToken)) == address(0)) {
      uniswapLpTokenPriceOracle = new UniswapLpTokenPriceOracle(wtoken); // BTCB

      address[] memory underlyings = new address[](1);
      IPriceOracle[] memory oracles = new IPriceOracle[](1);

      underlyings[0] = lpToken;
      oracles[0] = IPriceOracle(uniswapLpTokenPriceOracle);

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

    uint256 price = getLpTokenPrice(lpToken);
    assertTrue(price > 0);
  }

  function testGlmrUsdcLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0xb929914B89584b4081C7966AC6287636F7EfD053; // Lp GLMR-USDC

    uint256 price = getLpTokenPrice(lpToken);
    assertTrue(price > 0);
  }

  function testGlmrGlintLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0x99588867e817023162F4d4829995299054a5fC57; // Lp GLMR-GLINT

    uint256 price = getLpTokenPrice(lpToken);
    assertTrue(price > 0);
  }

  function testWGlmrWethLpTokenOraclePrice() public fork(MOONBEAM_MAINNET) {
    address lpToken = 0x8577273FB3B72306F3A59E26ab77116f5D428DAa; // Lp GLMR-GLINT

    uint256 price = getLpTokenPrice(lpToken);
    assertTrue(price > 0);
  }
}
