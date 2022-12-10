// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { FluxPriceOracle } from "../../../oracles/default/FluxPriceOracle.sol";
import { CLV2V3Interface } from "../../../external/flux/CLV2V3Interface.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { NativeUSDPriceOracle } from "../../../oracles/evmos/NativeUSDPriceOracle.sol";

contract FluxPriceOracleTest is BaseTest {
  FluxPriceOracle private oracle;
  MasterPriceOracle private mpo;

  CLV2V3Interface FLUX_ETH_USD_FEED = CLV2V3Interface(0x4C8f111a1048fEc7Ea9c9cbAB96a2cB5d1B94560);
  CLV2V3Interface FLUX_FRAX_USD_FEED = CLV2V3Interface(0x71712f8142550C0f76719Bc958ba0C28c4D78985);
  CLV2V3Interface FLUX_USDC_USD_FEED = CLV2V3Interface(0x3B2AF9149360e9F954C18f280aD0F4Adf1B613b8);

  address ADRASTIA_EVMOS_USD_FEED = 0xd850F64Eda6a62d625209711510f43cD49Ef8798;
  address WEVMOS = 0xD4949664cD82660AaE99bEdc034a0deA8A0bd517;

  NativeUSDPriceOracle private nativeUSDOracle;

  function setUpMpo() public {
    SimplePriceOracle spo = new SimplePriceOracle();
    spo.setDirectPrice(address(2), 200000000000000000); // 1e36 / 200000000000000000 = 5e18

    mpo = new MasterPriceOracle();
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(2);
    IPriceOracle[] memory oracles = new IPriceOracle[](1);
    oracles[0] = IPriceOracle(address(spo));
    mpo.initialize(underlyings, oracles, IPriceOracle(address(spo)), address(this), true, address(0));

    oracle = new FluxPriceOracle();
    nativeUSDOracle = new NativeUSDPriceOracle();

    vm.prank(nativeUSDOracle.owner());
    nativeUSDOracle.initialize(ADRASTIA_EVMOS_USD_FEED, WEVMOS);
    vm.prank(oracle.owner());
    oracle.initialize(nativeUSDOracle);
  }

  function setUpFluxFeed() public {
    setUpMpo();
    // ETH/USD on EVMOS mainnet
    address[] memory underlyings = new address[](3);
    underlyings[0] = address(1);
    underlyings[1] = address(2);
    underlyings[2] = address(3);

    CLV2V3Interface[] memory priceFeeds = new CLV2V3Interface[](3);
    priceFeeds[0] = FLUX_ETH_USD_FEED;
    priceFeeds[1] = FLUX_FRAX_USD_FEED;
    priceFeeds[2] = FLUX_USDC_USD_FEED;
    vm.prank(oracle.owner());
    oracle.setPriceFeeds(underlyings, priceFeeds);
  }

  function testFluxPriceOracle() public forkAtBlock(EVMOS_MAINNET, 8256599) {
    setUpFluxFeed();
    vm.prank(address(mpo));
    uint256 ethPrice = oracle.price(address(1));
    assertEq(ethPrice, 2586253748621296444418);

    uint256 fraxPrice = oracle.price(address(2));
    assertEq(fraxPrice, 2104240239620782851);

    uint256 usdcPrice = oracle.price(address(3));
    assertApproxEqRel(fraxPrice, usdcPrice, 1e16, "delta between usdc and frax > 1%");
  }
}
