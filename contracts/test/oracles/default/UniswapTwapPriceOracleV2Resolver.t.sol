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

  struct Observation {
    uint32 timestamp;
    uint256 price0Cumulative;
    uint256 price1Cumulative;
  }

  function afterForkSetUp() internal override { // forkAtBlock(MOONBEAM_MAINNET, 1824921) {
    uniswapV2Factory = IUniswapV2Factory(ap.getAddress("IUniswapV2Factory"));
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function getTokenTwapPrice(address tokenAddress) internal view returns (uint256) {
    // return the price denominated in W_NATIVE
    return mpo.price(tokenAddress);
  }

  function testStellaWglmrPriceUpdate() public fork(MOONBEAM_MAINNET) {
    twapPriceOracleRoot = UniswapTwapPriceOracleV2Root(0x7645f0A9F814286857E937cB1b3fa9659B03385b); // TODO: add to ap

    address STELLA_WGLMR = 0x7F5Ac0FC127bcf1eAf54E3cd01b00300a0861a62; // STELLA/WGLMR
    address CELR_WGLMR = 0xd47BeC28365a82C0C006f3afd617012B02b129D6; // CELR/WGLMR
    address wglmr = 0xAcc15dC74880C9944775448304B263D191c6077F; // WBNB
    uint256 observationCount = twapPriceOracleRoot.observationCount(STELLA_WGLMR);
    emit log_named_uint("STELLA_WGLMR observationCount: ", observationCount);
    {
      (, , uint32 lastTime) = IUniswapV2Pair(STELLA_WGLMR).getReserves();
      emit log_named_uint("STELLA_WGLMR last time: ", lastTime);
      (uint32 timestamp, uint256 price0Cumulative, uint256 price1Cumulative) = twapPriceOracleRoot.observations(
        STELLA_WGLMR,
        0
      );
      emit log_named_uint("STELLA_WGLMR observations timestamp: ", timestamp);
      emit log_named_bytes(
        "STELLA_WGLMR observations timestamp diff: ",
        abi.encode(block.timestamp - timestamp > 15 minutes)
      );
      emit log_named_uint("STELLA_WGLMR observations price0Cumulative: ", price0Cumulative);
    }
    UniswapTwapPriceOracleV2Resolver.PairConfig[]
      memory pairConfigs = new UniswapTwapPriceOracleV2Resolver.PairConfig[](0);
    resolver = new UniswapTwapPriceOracleV2Resolver(pairConfigs, twapPriceOracleRoot);

    UniswapTwapPriceOracleV2Resolver.PairConfig memory pairConfig = UniswapTwapPriceOracleV2Resolver.PairConfig({
      pair: STELLA_WGLMR,
      baseToken: wglmr,
      minPeriod: 1800,
      deviationThreshold: 50000000000000000
    });
    resolver.addPair(pairConfig);

    pairConfig = UniswapTwapPriceOracleV2Resolver.PairConfig({
      pair: CELR_WGLMR,
      baseToken: wglmr,
      minPeriod: 1800,
      deviationThreshold: 0
    });
    resolver.addPair(pairConfig);

    address[] memory workablePairs = resolver.getWorkablePairs();
    emit log_named_uint("workablePairs: ", workablePairs.length);
    for (uint256 i = 0; i < workablePairs.length; i++) {
      emit log_named_address("workablePairs: ", workablePairs[i]);
    }
    (bool canExec, bytes memory execPayload) = resolver.checker();
    emit log_named_bytes("canExec: ", abi.encode(canExec));
    emit log_named_bytes("execPayload: ", execPayload);
    assertTrue(canExec, "!can exec");
    assertEq(abi.encodeWithSelector(resolver.updatePairs.selector, workablePairs), execPayload, "!payload");

    resolver.updatePairs(workablePairs);

    // assertTrue(getTokenTwapPrice(STELLA_WGLMR) > 0);
    // assertTrue(getTokenTwapPrice(CELR_WGLMR) > 0);
  }
}
