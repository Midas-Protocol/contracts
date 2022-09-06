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
    twapPriceOracleRoot = UniswapTwapPriceOracleV2Root(0x7645f0A9F814286857E937cB1b3fa9659B03385b); // TODO: add to ap
    uniswapV2Factory = IUniswapV2Factory(ap.getAddress("IUniswapV2Factory"));
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    UniswapTwapPriceOracleV2Resolver.PairConfig[] memory pairs = new UniswapTwapPriceOracleV2Resolver.PairConfig[](0);
    resolver = new UniswapTwapPriceOracleV2Resolver(pairs, twapPriceOracleRoot);
  }

  function getTokenTwapPrice(address tokenAddress) internal returns (uint256) {
    // return the price denominated in W_NATIVE
    return mpo.price(tokenAddress);
  }

  function testUniswapTwapResolve() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    UniswapTwapPriceOracleV2Resolver resolver = UniswapTwapPriceOracleV2Resolver(0x84514D194192851e5080940824623Db973A0d557);
    address[] memory pairs1 = new address[](2);
    address[] memory baseTokens = new address[](2);
    uint256[] memory minPeriods = new uint256[](2);
    uint256[] memory deviationThresholds = new uint256[](2);
    pairs1[0] = 0x7F5Ac0FC127bcf1eAf54E3cd01b00300a0861a62;
    pairs1[1] = 0xd47BeC28365a82C0C006f3afd617012B02b129D6;
    baseTokens[0] = 0xAcc15dC74880C9944775448304B263D191c6077F;
    baseTokens[1] = 0xAcc15dC74880C9944775448304B263D191c6077F;
    minPeriods[0] = 1800;
    minPeriods[1] = 1800;
    deviationThresholds[0] = 50000000000000000;
    deviationThresholds[0] = 50000000000000000;

    bool[] memory res = twapPriceOracleRoot.workable(pairs1, baseTokens, minPeriods, deviationThresholds);

    address[] memory pairs = resolver.getWorkablePairs();
    for (uint256 i = 0; i < pairs.length; i += 1) {
      if (res[i]) {
        emit log("true");
      } else {
        emit log("false");
      }
      emit log_address(pairs[i]);
    }
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
