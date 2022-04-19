// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../oracles/MasterPriceOracle.sol";
import "../oracles/default/UniswapLpTokenPriceOracle.sol";
import "./config/BaseTest.t.sol";

contract UniswapLpTokenBaseTest is BaseTest {
  UniswapLpTokenPriceOracle uniswapLpTokenPriceOracle;
  MasterPriceOracle mpo;

  function setUp() public {
    mpo = chainConfig.masterPriceOracle;
  }

  function getLpTokenPrice (address tokenAddress, address baseTokenAddress) internal returns (uint256) {
    emit log("inside getLpTokenPrice");
    emit log_address(address(mpo.oracles(tokenAddress)));
    // if (address(mpo.oracles(tokenAddress)) == address(0)) {
    //   emit log("creating oracle");
    //   uniswapLpTokenPriceOracle = UniswapLpTokenPriceOracle(baseTokenAddress);

    //   address[] memory underlyings = new address[](1);
    //   underlyings[0] = tokenAddress;
    //   IPriceOracle[] memory oracles = new IPriceOracle[](1);
    //   oracles[0] = IPriceOracle(uniswapLpTokenPriceOracle);

    //   vm.prank(mpo.admin());
    //   mpo.add(underlyings, oracles);
    //   emit log("added the oracle");
    // } else {
    //   emit log("found the oracle");
    // }
    // emit log("before getting price");
    return mpo.price(tokenAddress);
  }

  function testBombBtcLpTokenOraclePrice() public shouldRun(forChains(BSC_MAINNET)) {
    address baseToken = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c; // BTCB
    address lpToken = 0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6; // Lp BOMB-BTCB
    emit log_address(lpToken);
    uint256 price = getLpTokenPrice(lpToken, baseToken);
    // emit log_uint(price);
    // assertTrue(price > 0);
  }
}