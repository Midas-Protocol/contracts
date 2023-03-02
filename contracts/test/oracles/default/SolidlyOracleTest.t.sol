// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { SolidlyOracle } from "../../../oracles/default/SolidlyOracle.sol";
import { IPair } from "../../../external/solidly/IPair.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";

struct PriceExpected {
  uint256 price;
  uint256 percentErrorAllowed;
}

contract SolidlyPriceOracleTest is BaseTest {
  SolidlyOracle oracle;
  MasterPriceOracle mpo;
  address wtoken;
  address stable;

  function afterForkSetUp() internal override {
    // Not using the address provider yet -- config just added
    // TODO: use ap when deployment is done

    stable = ap.getAddress("stableToken"); // USDC
    wtoken = ap.getAddress("wtoken"); // WETH
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new SolidlyOracle();

    vm.prank(mpo.admin());
    oracle.initialize(wtoken, asArray(stable));
  }

  function testBscAssets() public fork(BSC_MAINNET) {
    address busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address usdt = 0x55d398326f99059fF775485246999027B3197955;
    address hay = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
    address bnbx = 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275;
    address eth = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;

    address[] memory underlyings = new address[](4);
    SolidlyOracle.AssetConfig[] memory configs = new SolidlyOracle.AssetConfig[](4);

    underlyings[0] = hay; // HAY
    underlyings[1] = bnbx; // BNBx
    underlyings[2] = eth; // ETH
    underlyings[3] = usdt; // USDT

    // HAY/BUSD
    configs[0] = SolidlyOracle.AssetConfig(0x93B32a8dfE10e9196403dd111974E325219aec24, busd);
    // BNBx/WBNB
    configs[1] = SolidlyOracle.AssetConfig(0x6c83E45fE3Be4A9c12BB28cB5BA4cD210455fb55, wtoken);
    // ETH/WBNB
    configs[2] = SolidlyOracle.AssetConfig(0x1d168C5b5DEa1c6dA0E9FD9bf4B7607e4e9D8EeC, wtoken);
    // USDT/BUSD
    configs[3] = SolidlyOracle.AssetConfig(0x6321B57b6fdc14924be480c54e93294617E672aB, busd);

    PriceExpected[] memory expPrices = new PriceExpected[](4);

    expPrices[0] = PriceExpected({ price: mpo.price(hay), percentErrorAllowed: 1e18 }); // 1%
    expPrices[1] = PriceExpected({ price: mpo.price(bnbx), percentErrorAllowed: 1e18 }); // 1%
    expPrices[2] = PriceExpected({ price: mpo.price(eth), percentErrorAllowed: 1e17 }); // 1%
    expPrices[3] = PriceExpected({ price: mpo.price(usdt), percentErrorAllowed: 1e17 }); // 1%

    emit log_named_uint("USDC PRICE", mpo.price(stable));
    uint256[] memory prices = getPriceFeed(underlyings, configs);
    for (uint256 i = 0; i < prices.length; i++) {
      assertApproxEqRel(prices[i], expPrices[i].price, expPrices[i].percentErrorAllowed, "!Price Error");
    }
  }

  function getPriceFeed(address[] memory underlyings, SolidlyOracle.AssetConfig[] memory configs)
    internal
    returns (uint256[] memory price)
  {
    vm.prank(oracle.owner());
    oracle.setPoolFeeds(underlyings, configs);
    vm.roll(1);

    price = new uint256[](underlyings.length);
    for (uint256 i = 0; i < underlyings.length; i++) {
      emit log_named_address("UL", underlyings[i]);
      vm.prank(address(mpo));
      price[i] = oracle.price(underlyings[i]);
    }
    return price;
  }
}
