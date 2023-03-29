// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { ERC4626Oracle } from "../../../oracles/default/ERC4626Oracle.sol";
import { SimplePriceOracle } from "../../../oracles/default/SimplePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { IPriceOracle } from "../../../external/compound/IPriceOracle.sol";
import { IPriceOracle as IAdrastiaPriceOracle } from "adrastia/interfaces/IPriceOracle.sol";
import { ChainlinkPriceOracleV2 } from "../../../oracles/default/ChainlinkPriceOracleV2.sol";

contract ERC4626OracleTest is BaseTest {
  MasterPriceOracle mpo;
  ChainlinkPriceOracleV2 chainlinkOracle;
  ERC4626Oracle erc4626Oracle;

  address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address realYieldUSDVault = 0x97e6E0a40a3D02F12d1cEC30ebfbAE04e37C119E;
  address nativeUsdPriceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  address usdcUsdPriceFeed = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;

  function setUpMpo() public {
    address[] memory assets = new address[](0);
    IPriceOracle[] memory oracles = new IPriceOracle[](0);
    mpo = new MasterPriceOracle();
    mpo.initialize(assets, oracles, IPriceOracle(address(0)), address(this), true, WETH);
  }

  function setUpOtherOracles() public {
    setUpMpo();
    IPriceOracle[] memory oracles = new IPriceOracle[](2);
    chainlinkOracle = new ChainlinkPriceOracleV2(mpo.admin(), true, WETH, nativeUsdPriceFeed);
    vm.prank(chainlinkOracle.admin());
    chainlinkOracle.setPriceFeeds(
      asArray(USDC),
      asArray(usdcUsdPriceFeed),
      ChainlinkPriceOracleV2.FeedBaseCurrency.USD
    );
    oracles[0] = IPriceOracle(address(chainlinkOracle));

    erc4626Oracle = new ERC4626Oracle();
    vm.prank(erc4626Oracle.owner());
    erc4626Oracle.initialize();
    oracles[1] = IPriceOracle(address(erc4626Oracle));

    vm.prank(mpo.admin());
    mpo.add(asArray(USDC, realYieldUSDVault), oracles);
  }

  function testErc4626aPriceOracle() public fork(ETHEREUM_MAINNET) {
    setUpOtherOracles();
    uint256 priceRy = mpo.price(realYieldUSDVault);
    emit log_named_uint("priceRy", priceRy);
  }
}
