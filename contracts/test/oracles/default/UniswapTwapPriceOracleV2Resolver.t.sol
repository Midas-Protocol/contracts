// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../../oracles/MasterPriceOracle.sol";
import "../../../oracles/default/UniswapTwapPriceOracleV2Root.sol";
import "../../../oracles/default/UniswapTwapPriceOracleV2Factory.sol";
import "../../../external/uniswap/IUniswapV2Factory.sol";
import "../../config/BaseTest.t.sol";
import { UniswapTwapPriceOracleV2Resolver } from "../../../oracles/default/UniswapTwapPriceOracleV2Resolver.sol";

contract UniswapTwapOracleV2ResolverTest is BaseTest {
  UniswapTwapPriceOracleV2Root twapPriceOracleRoot;
  UniswapTwapPriceOracleV2Resolver resolver;
  IUniswapV2Factory uniswapV2Factory;
  MasterPriceOracle mpo;

  function setUp() public {
    twapPriceOracleRoot = UniswapTwapPriceOracleV2Root(0x81D71C46615320Ba4fbbD9fDFA6310ef93A92f31); // TODO: add to ap
    uniswapV2Factory = IUniswapV2Factory(ap.getAddress("IUniswapV2Factory"));
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    UniswapTwapPriceOracleV2Resolver.PairConfig[] memory pairs = new UniswapTwapPriceOracleV2Resolver.PairConfig[](0);
    resolver = new UniswapTwapPriceOracleV2Resolver(pairs, twapPriceOracleRoot);
  }

  function getTokenTwapPrice(address tokenAddress) internal returns (uint256) {
    // return the price denominated in W_NATIVE
    return mpo.price(tokenAddress);
  }

  // BUSD DAI
  function testBusdDaiPriceUpdate() public shouldRun(forChains(BSC_MAINNET)) {
    address WBNB_BUSD = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16; // WBNB-BUSD
    address WBNB_DAI = 0xc7c3cCCE4FA25700fD5574DA7E200ae28BBd36A3; // WBNB-DAI
    address wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB

    UniswapTwapPriceOracleV2Resolver.PairConfig memory pairConfig = UniswapTwapPriceOracleV2Resolver.PairConfig({
      pair: WBNB_BUSD,
      baseToken: wbnb,
      minPeriod: 1800,
      deviationThreshold: 50000000000000000
    });

    resolver.addPair(pairConfig);
    pairConfig = UniswapTwapPriceOracleV2Resolver.PairConfig({
      pair: WBNB_DAI,
      baseToken: wbnb,
      minPeriod: 1800,
      deviationThreshold: 50000000000000000
    });
    resolver.addPair(pairConfig);

    address[] memory workablePairs = resolver.getWorkablePairs();
    emit log_named_bytes("workablePairs: ", abi.encode(workablePairs));
    (bool canExec, bytes memory execPayload) = resolver.checker();
    emit log_named_bytes("execPayload: ", execPayload);
    assertTrue(canExec);
    assertEq(abi.encodeWithSelector(resolver.updatePairs.selector, workablePairs), execPayload);

    resolver.updatePairs(workablePairs);

    assertTrue(getTokenTwapPrice(WBNB_BUSD) > 0);
    assertTrue(getTokenTwapPrice(WBNB_DAI) > 0);
  }
}
