// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { AdrastiaPriceOracle } from "../../../oracles/default/AdrastiaPriceOracle.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { IPriceOracle as IAdrastiaPriceOracle } from "adrastia/interfaces/IPriceOracle.sol";
import { NativeUSDPriceOracle } from "../../../oracles/evmos/NativeUSDPriceOracle.sol";

contract AdrastiaPriceOracleTest is BaseTest {
  AdrastiaPriceOracle private oracle;

  address gUSDC = 0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687;
  address axlWETH = 0x50dE24B3f0B3136C50FA8A3B8ebc8BD80a269ce5;
  address ADRASTIA_EVMOS_USD_FEED = 0xd850F64Eda6a62d625209711510f43cD49Ef8798;
  address ADASTRIA_XXX_EVMOS_FEED = 0x51d3d22965Bb2CB2749f896B82756eBaD7812b6d;

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
    nativeUSDOracle.initialize(ADRASTIA_EVMOS_USD_FEED);
    oracle.initialize(nativeUSDOracle);
    vm.stopPrank();
  }

  function setUpAdrastiaFeeds() public {
    setUpMpo();
    IAdrastiaPriceOracle evmosBasedFeed = IAdrastiaPriceOracle(ADASTRIA_XXX_EVMOS_FEED);
    address[] memory underlyings = new address[](2);
    underlyings[0] = gUSDC;
    underlyings[1] = axlWETH;

    IAdrastiaPriceOracle[] memory priceFeeds = new IAdrastiaPriceOracle[](2);
    priceFeeds[0] = evmosBasedFeed;
    priceFeeds[1] = evmosBasedFeed;

    vm.prank(oracle.owner());
    oracle.setPriceFeeds(underlyings, priceFeeds);
  }

  function testAdrastiaPriceOracle() public forkAtBlock(EVMOS_MAINNET, 7581139) {
    setUpAdrastiaFeeds();
    uint256 priceGUsdc = oracle.price(gUSDC);
    assertEq(priceGUsdc, 1069746906351096056);

    uint256 priceEth = oracle.price(axlWETH);
    assertEq(priceEth, 1257026900818360167013);
  }
}
