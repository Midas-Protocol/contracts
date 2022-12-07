// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { BaseTest } from "./config/BaseTest.t.sol";

import { WombatLpTokenLiquidator } from "../liquidators/WombatLpTokenLiquidator.sol";
import { IWombatLpAsset } from "../oracles/default/WombatLpTokenPriceOracle.sol";
import { WombatLpTokenPriceOracle } from "../oracles/default/WombatLpTokenPriceOracle.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";

contract WombatLpTokenLiquidatorTest is BaseTest {
  WombatLpTokenLiquidator private wtl;
  WombatLpTokenPriceOracle private oracle;
  MasterPriceOracle private mp;

  function afterForkSetUp() internal override {
    wtl = new WombatLpTokenLiquidator();
    oracle = new WombatLpTokenPriceOracle();
    mp = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
  }

  function testRedeemWBNB() public forkAtBlock(BSC_MAINNET, 21547774) {
    address wombatWBNB = 0x74f019A5C4eD2C2950Ce16FaD7Af838549092c5b;
    uint256 assetAmount = 100e18;

    deal(wombatWBNB, address(wtl), assetAmount);

    vm.prank(address(mp));
    uint256 assetPrice = oracle.price(wombatWBNB); // wombatWBNB price
    uint256 underlyingPrice = mp.price(IWombatLpAsset(wombatWBNB).underlyingToken()); // wbnb price

    // amount convertion = assetAmount * underlyingPrice / assetPrice
    uint256 expectedAmount = (assetAmount * underlyingPrice) / assetPrice;

    bytes memory strategyData = abi.encode(
      IWombatLpAsset(wombatWBNB).pool(),
      IWombatLpAsset(wombatWBNB).underlyingToken()
    );
    (, uint256 redeemAmount) = wtl.redeem(IERC20Upgradeable(wombatWBNB), assetAmount, strategyData);

    assertApproxEqAbs(
      expectedAmount,
      redeemAmount,
      uint256(1e17),
      string(abi.encodePacked("!redeemAmount == expectedAmount "))
    );
  }
}
