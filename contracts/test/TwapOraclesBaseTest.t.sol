// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../oracles/MasterPriceOracle.sol";
import "../oracles/default/UniswapTwapPriceOracleV2Factory.sol";
import "../external/uniswap/IUniswapV2Factory.sol";
import "./config/BaseTest.t.sol";

contract TwapOraclesBaseTest is BaseTest {
  IUniswapV2Factory uniswapV2Factory;
  UniswapTwapPriceOracleV2Factory twapPriceOracleFactory;
  MasterPriceOracle mpo;

  function setUp() public {
    uniswapV2Factory = chainConfig.uniswapV2Factory;
    twapPriceOracleFactory = chainConfig.twapOraclesFactory;
    mpo = chainConfig.masterPriceOracle;
  }

  function getTokenTwapPrice(address tokenAddress, address baseTokenAddress) internal returns (uint256) {
    address testedPairAddress = uniswapV2Factory.getPair(tokenAddress, baseTokenAddress);

    // trigger a price update
    UniswapTwapPriceOracleV2Root twapOracleRoot = UniswapTwapPriceOracleV2Root(twapPriceOracleFactory.rootOracle());
    address[] memory pairs = new address[](1);
    pairs[0] = testedPairAddress;
    twapOracleRoot.update(pairs);

    // check if the base toke oracle is present in the master price oracle
    if (address(mpo.oracles(tokenAddress)) == address(0)) {
      // deploy or get the base token twap oracle
      address oracleAddress = twapPriceOracleFactory.deploy(address(uniswapV2Factory), baseTokenAddress);
      UniswapTwapPriceOracleV2 oracle = UniswapTwapPriceOracleV2(oracleAddress);
      // add the new twap oracle to the master oracle
      address[] memory underlyings = new address[](1);
      underlyings[0] = tokenAddress;
      IPriceOracle[] memory oracles = new IPriceOracle[](1);
      oracles[0] = IPriceOracle(oracle);
      // impersonate the admin to add the oracle
      vm.prank(mpo.admin());
      mpo.add(underlyings, oracles);
      emit log("added the oracle");
    } else {
      emit log("found the oracle");
    }

    // return the price denominated in W_NATIVE
    return mpo.price(tokenAddress);
  }

  // BOMB
  function testBombTwapOraclePrice() public shouldRun(forChains(BSC_MAINNET)) {
    address baseToken = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c; // WBTC
    address testedAssetTokenAddress = 0x522348779DCb2911539e76A1042aA922F9C47Ee3; // BOMB

    assertTrue(getTokenTwapPrice(testedAssetTokenAddress, baseToken) > 0);
  }

  function testChapelEthBusdOraclePrice() public shouldRun(forChains(97)) {
    address baseToken = 0xd66c6B4F0be8CE5b39D52E0Fd1344c389929B378; // ETH
    address testedAssetTokenAddress = 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee; // BUSD

    assertTrue(getTokenTwapPrice(testedAssetTokenAddress, baseToken) > 0);
  }
}
