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
  IUniswapV2Factory uniswapV2Factory;
  UniswapTwapPriceOracleV2Root rootOracle;
  MasterPriceOracle mpo;
  address wtoken;

  function setUp() public {
    wtoken = address(chainConfig.weth);
    // uniswapV2Factory = chainConfig.uniswapV2Factory;
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

      // address token0 = pair.token0();
      // address token1 = pair.token1();
      // address[] memory underlyings = new address[](1);
      // IPriceOracle[] memory oracles = new IPriceOracle[](1);

      // if (mpo.oracles(token0) == IPriceOracle(address(0)) || mpo.oracles(token1) == IPriceOracle(address(0))) {
      //   rootOracle = new UniswapTwapPriceOracleV2Root(wtoken);
      // }

      // if (mpo.oracles(token0) == IPriceOracle(address(0))) {
      //   UniswapTwapPriceOracleV2 token0Oracle = new UniswapTwapPriceOracleV2();
      //   token0Oracle.initialize(address(rootOracle), address(uniswapV2Factory), wtoken, wtoken);
      //   rootOracle.update(token0);

      //   underlyings[0] = token0;
      //   oracles[0] = IPriceOracle(token0Oracle);
      //   vm.prank(mpo.admin());
      //   mpo.add(underlyings, oracles);
      //   emit log("token 0 oracle added");
      // }

      // if (mpo.oracles(token1) == IPriceOracle(address(0))) {
      //   UniswapTwapPriceOracleV2 token1Oracle = new UniswapTwapPriceOracleV2();
      //   token1Oracle.initialize(address(rootOracle), address(uniswapV2Factory), wtoken, wtoken);
        
      //   rootOracle.update(token1);
      //   underlyings[0] = token1;
      //   oracles[0] = IPriceOracle(token1Oracle);
      //   vm.prank(mpo.admin());
      //   mpo.add(underlyings, oracles);
      //   emit log("token 1 oracle added");
      // }

      underlyings[0] = lpToken;
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
    address lpToken = 0xb929914B89584b4081C7966AC6287636F7EfD053; // Lp GLMR-USDC

    uint256 price = getLpTokenPrice(lpToken);
    emit log_uint(price);
    // assertTrue(price > 0);
  }
}