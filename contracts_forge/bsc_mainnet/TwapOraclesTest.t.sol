// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../contracts/oracles/MasterPriceOracle.sol";
import "../../contracts/oracles/default/UniswapTwapPriceOracleV2Factory.sol";
import "../../contracts/external/uniswap/IUniswapV2Factory.sol";
import {BscMainnetBaseTest} from "../config/BaseTest.t.sol";

contract TwapOraclesTest is BscMainnetBaseTest {
  address masterPriceOracleAddress = 0x37CF9eA8C6Bb6C020D4B5e7C3C462B02313aaFF4;
  address twapOraclesFactoryAddress = 0x98EC86b8d2CbAf5329A032b4F655CF0ff6cc029a;
  address uniswapV2FactoryAddress = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;

  function getTokenTwapPrice(address tokenAddress, address baseTokenAddress) internal returns (uint256) {
    IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(uniswapV2FactoryAddress);
    address testedPairAddress = uniswapV2Factory.getPair(tokenAddress, baseTokenAddress);

    UniswapTwapPriceOracleV2Factory twapPriceOracleFactory = UniswapTwapPriceOracleV2Factory(twapOraclesFactoryAddress);

    // trigger a price update
    UniswapTwapPriceOracleV2Root twapOracleRoot = UniswapTwapPriceOracleV2Root(twapPriceOracleFactory.rootOracle());
    address[] memory pairs = new address[](1);
    pairs[0] = testedPairAddress;
    twapOracleRoot.update(pairs);

    // check if the base toke oracle is present in the master price oracle
    MasterPriceOracle mpo = MasterPriceOracle(masterPriceOracleAddress);
    if (address(mpo.oracles(tokenAddress)) == address(0)) {
      // deploy or get the base token twap oracle
      address oracleAddress = twapPriceOracleFactory.deploy(uniswapV2FactoryAddress, baseTokenAddress);
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
  function testBombTwapOraclePrice() public {
    address baseToken = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c; // WBTC
    address testedAssetTokenAddress = 0x522348779DCb2911539e76A1042aA922F9C47Ee3; // BOMB

    assertTrue(getTokenTwapPrice(testedAssetTokenAddress, baseToken) > 0);
  }
}
