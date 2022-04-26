// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../oracles/MasterPriceOracle.sol";
import "../external/compound/IPriceOracle.sol";
import "../oracles/default/UniswapLpTokenPriceOracle.sol";
import "./config/BaseTest.t.sol";
import "../external/uniswap/IUniswapV2Pair.sol";

contract UniswapLpTokenBaseTest is BaseTest {
  UniswapLpTokenPriceOracle uniswapLpTokenPriceOracle;
  MasterPriceOracle mpo;
  address wtoken;

  function setUp() public {
    wtoken = address(chainConfig.weth);
    if (address(chainConfig.masterPriceOracle) == address(0)) {
      MasterPriceOracle masterPriceOracle = new MasterPriceOracle();
      address[] memory _underlyings;
      IPriceOracle[] memory _oracles;
      masterPriceOracle.initialize(_underlyings, _oracles, IPriceOracle(address(0)), address(1),true, wtoken);
      mpo = masterPriceOracle;
    } else {
      mpo = chainConfig.masterPriceOracle;
    }
  }

  function getLpTokenPrice (address lpToken) internal returns (uint256) {
    if (address(mpo.oracles(lpToken)) == address(0)) {
      uniswapLpTokenPriceOracle = new UniswapLpTokenPriceOracle(wtoken); // BTCB 
      IUniswapV2Pair pair = IUniswapV2Pair(lpToken);

      address[] memory underlyings = new address[](1);
      underlyings[0] = lpToken;
      IPriceOracle[] memory oracles = new IPriceOracle[](1);
      oracles[0] = IPriceOracle(uniswapLpTokenPriceOracle);

      vm.prank(mpo.admin());
      mpo.add(underlyings, oracles);
      emit log("added the oracle");
    } else {
      emit log("found the oracle");
    }
    emit log_address(lpToken);
    return mpo.price(lpToken);
  }

  function testBombBtcLpTokenOraclePrice() public shouldRun(forChains(BSC_MAINNET)) {
    address lpToken = 0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6; // Lp BOMB-BTCB

    uint256 price = getLpTokenPrice(lpToken);
    assertTrue(price > 0);
  }

  function testGlmrUsdcLpTokenOraclePrice() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    address lpToken = 0x99588867e817023162F4d4829995299054a5fC57; // Lp GLMR-USDC

    uint256 price = getLpTokenPrice(lpToken);
    emit log_uint(price);
    // assertTrue(price > 0);
  }
}