// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../oracles/MasterPriceOracle.sol";
import "../external/compound/IPriceOracle.sol";
import "../oracles/default/UniswapTwapPriceOracleV2.sol";
import "../oracles/default/UniswapTwapPriceOracleV2Root.sol";
import "../oracles/default/UniswapLpTokenPriceOracle.sol";
import "./config/BaseTest.t.sol";
import "../external/uniswap/IUniswapV2Pair.sol";
import "../external/uniswap/IUniswapV2Factory.sol";

contract UniswapLpTokenBaseTest is BaseTest {
  UniswapLpTokenPriceOracle uniswapLpTokenPriceOracle;
  MasterPriceOracle mpo;
  address wtoken;

  function setUp() public {
    wtoken = address(chainConfig.weth);
    mpo = chainConfig.masterPriceOracle;
  }

  function getLpTokenPrice(address lpToken) internal returns (uint256) {
    if (address(mpo.oracles(lpToken)) == address(0)) {
      uniswapLpTokenPriceOracle = new UniswapLpTokenPriceOracle(wtoken); // BTCB
      IUniswapV2Pair pair = IUniswapV2Pair(lpToken);

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

  function testBombBtcLpTokenOraclePrice() public shouldRun(forChains(BSC_MAINNET)) {
    address lpToken = 0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6; // Lp BOMB-BTCB

    uint256 price = getLpTokenPrice(lpToken);
    assertTrue(price > 0);
  }

  function testGlmrUsdcLpTokenOraclePrice() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    address lpToken = 0xb929914B89584b4081C7966AC6287636F7EfD053; // Lp GLMR-USDC

    uint256 price = getLpTokenPrice(lpToken);
    assertTrue(price > 0);
  }

  function testGlmrGlintLpTokenOraclePrice() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    address lpToken = 0x99588867e817023162F4d4829995299054a5fC57; // Lp GLMR-GLINT

    uint256 price = getLpTokenPrice(lpToken);
    assertTrue(price > 0);
  }
}
