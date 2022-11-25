// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { AdrastiaPriceOracle } from "../../../oracles/default/AdrastiaPriceOracle.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { IPriceOracle as IAdrastiaPriceOracle } from "adrastia/interfaces/IPriceOracle.sol";
import { NativeUSDPriceOracle } from "../../../oracles/evmos/NativeUSDPriceOracle.sol";

contract MockAdrastiaPriceOracle {
  uint112 public staticPrice;
  uint8 public staticDecimals;

  constructor(uint112 _staticPrice, uint8 _staticDecimals) {
    staticPrice = _staticPrice;
    staticDecimals = _staticDecimals;
  }

  function quoteTokenDecimals() public view virtual returns (uint8) {
    return staticDecimals;
  }

  function consultPrice(address token) public view virtual returns (uint112 price) {
    return staticPrice;
  }
}

contract AdrastiaPriceOracleTest is BaseTest {
  AdrastiaPriceOracle private oracle;

  address gUSDC = 0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687;
  address gUSDT = 0xecEEEfCEE421D8062EF8d6b4D814efe4dc898265;
  address gDAI = 0xd567B3d7B8FE3C79a1AD8dA978812cfC4Fa05e75;

  address ceWETH = 0x153A59d48AcEAbedbDCf7a13F67Ae52b434B810B;
  address axlWETH = 0x50dE24B3f0B3136C50FA8A3B8ebc8BD80a269ce5;

  address axlWBTC = 0xF5b24c0093b65408ACE53df7ce86a02448d53b25;

  address ADRASTIA_EVMOS_USD_FEED = 0xd850F64Eda6a62d625209711510f43cD49Ef8798;
  address ADASTRIA_XXX_EVMOS_FEED = 0x51d3d22965Bb2CB2749f896B82756eBaD7812b6d;
  address WEVMOS = 0xD4949664cD82660AaE99bEdc034a0deA8A0bd517;

  function setUpMpo() public {
    SimplePriceOracle spo = new SimplePriceOracle();
    spo.setDirectPrice(address(2), 200000000000000000); // 1e36 / 200000000000000000 = 5e18

    MasterPriceOracle mpo = new MasterPriceOracle();
    address[] memory underlyings = new address[](1);
    underlyings[0] = address(2);
    IPriceOracle[] memory oracles = new IPriceOracle[](1);
    oracles[0] = IPriceOracle(address(spo));
    mpo.initialize(underlyings, oracles, IPriceOracle(address(spo)), address(this), true, address(0));

    oracle = new AdrastiaPriceOracle();
    NativeUSDPriceOracle nativeUSDOracle = new NativeUSDPriceOracle();

    vm.startPrank(oracle.owner());
    nativeUSDOracle.initialize(ADRASTIA_EVMOS_USD_FEED, WEVMOS);
    oracle.initialize(nativeUSDOracle);
    vm.stopPrank();
  }

  function setUpAdrastiaFeeds() public {
    setUpMpo();
    IAdrastiaPriceOracle evmosBasedFeed = IAdrastiaPriceOracle(ADASTRIA_XXX_EVMOS_FEED);

    // Stables
    address[] memory stableUnderlyings = new address[](3);
    stableUnderlyings[0] = gUSDC;
    stableUnderlyings[1] = gUSDT;
    stableUnderlyings[2] = gDAI;
    IAdrastiaPriceOracle[] memory stableFeeds = new IAdrastiaPriceOracle[](3);
    stableFeeds[0] = evmosBasedFeed;
    stableFeeds[1] = evmosBasedFeed;
    stableFeeds[2] = evmosBasedFeed;
    vm.prank(oracle.owner());
    oracle.setPriceFeeds(stableUnderlyings, stableFeeds);

    // Weth
    address[] memory wethUnderlyings = new address[](2);
    wethUnderlyings[0] = ceWETH;
    wethUnderlyings[1] = axlWETH;
    IAdrastiaPriceOracle[] memory wethFeeds = new IAdrastiaPriceOracle[](2);
    wethFeeds[0] = evmosBasedFeed;
    wethFeeds[1] = evmosBasedFeed;
    vm.prank(oracle.owner());
    oracle.setPriceFeeds(wethUnderlyings, wethFeeds);

    // Wbtc
    address[] memory wbtcUnderlyings = new address[](1);
    wbtcUnderlyings[0] = axlWBTC;
    IAdrastiaPriceOracle[] memory wbtcFeeds = new IAdrastiaPriceOracle[](1);
    wbtcFeeds[0] = evmosBasedFeed;
    vm.prank(oracle.owner());
    oracle.setPriceFeeds(wbtcUnderlyings, wbtcFeeds);

    IAdrastiaPriceOracle[] memory decimalsFeeds = new IAdrastiaPriceOracle[](2);
    // 28 decimals
    decimalsFeeds[0] = IAdrastiaPriceOracle(address(new MockAdrastiaPriceOracle(5e8, 8)));
    // 8 decimals
    decimalsFeeds[1] = IAdrastiaPriceOracle(address(new MockAdrastiaPriceOracle(5e28, 28)));
    vm.prank(oracle.owner());
    oracle.setPriceFeeds(asArray(address(2), address(3)), decimalsFeeds);
  }

  function testAdrastiaPriceOracle() public fork(EVMOS_MAINNET) {
    setUpAdrastiaFeeds();

    uint256 priceGUsdc = oracle.price(gUSDC);
    uint256 priceGUsdt = oracle.price(gUSDT);
    uint256 priceGDai = oracle.price(gDAI);

    uint256 priceCWeth = oracle.price(ceWETH);
    uint256 priceAxlWeth = oracle.price(axlWETH);

    uint256 priceAxlWbtc = oracle.price(axlWBTC);

    uint256 price28Decimals = oracle.price(address(2));
    uint256 price8Decimals = oracle.price(address(3));

    assertGt(priceGUsdc, 1e17);
    assertLt(priceGUsdc, 1e19);

    assertApproxEqRel(priceGUsdc, priceGUsdt, 5e16, "usd prices differ too much"); // 1e18 = 100%, 5e16 = 5%
    assertApproxEqRel(priceGUsdt, priceGDai, 5e16, "usd prices differ too much");

    assertApproxEqRel(priceCWeth, priceAxlWeth, 10e16, "eth prices differ too much");

    assertGt(priceAxlWbtc, priceAxlWeth);
    assertGt(priceAxlWeth, priceGUsdc);

    assertEq(price28Decimals, 5e18, "28 decimals price scaling is wrong");
    assertEq(price8Decimals, 5e18, "28 decimals price scaling is wrong");
  }
}
