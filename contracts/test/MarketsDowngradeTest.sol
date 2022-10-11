// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { MidasERC4626 } from "../midas/strategies/MidasERC4626.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract MarketsDowngradeTest is BaseTest {
  function testDowngradeMarket() public {
    address eurParAddress = 0x30b32BbfcA3A81922F88809F53E625b5EE5286f6; // PAR-jEUR LP
    address usdcParAddress = 0xa5A14c3814d358230a56e8f011B8fc97A508E890; // G-UNI USDC-PAR
    address twoNzdAddress = 0x7AB807F3FBeca9eb22a1A7a490bdC353D85DED41; // jNZD-NZDS

    // PAR-jEUR LP has 0 deposits
    // G-UNI USDC-PAR put on hold
    address market = twoNzdAddress;

    CErc20PluginDelegate asPluginMarket = CErc20PluginDelegate(market);

    address underlying = asPluginMarket.underlying();
    emit log("underlying is");
    emit log_address(underlying);

    MidasERC4626 asMidasPlugin = MidasERC4626(address(asPluginMarket.plugin()));

    emit log("plugin address is");
    emit log_address(address(asMidasPlugin));

    vm.prank(asMidasPlugin.owner());
    asMidasPlugin.emergencyWithdrawAndPause();

    uint256 assets = ERC20Upgradeable(underlying).balanceOf(market);

    emit log("withdrawn assets are");
    emit log_uint(assets);
  }
}
