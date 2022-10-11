// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { MidasERC4626 } from "../midas/strategies/MidasERC4626.sol";
import { BeefyERC4626 } from "../midas/strategies/BeefyERC4626.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MarketsDowngradeTest is BaseTest {
  // taken from ERC1967Upgrade
  bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

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

    address pluginAddress = address(asPluginMarket.plugin());
    MidasERC4626 asMidasPlugin = MidasERC4626(pluginAddress);

    emit log("plugin address is");
    emit log_address(address(asMidasPlugin));

    vm.prank(asMidasPlugin.owner());
    asMidasPlugin.emergencyWithdrawAndPause();

    uint256 assets = ERC20Upgradeable(underlying).balanceOf(market);

    emit log("withdrawn assets are");
    emit log_uint(assets);


    // upgrade
    {
      BeefyERC4626 newImpl = new BeefyERC4626();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(pluginAddress));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      //            emit log_address(admin);
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }


    vm.prank(asMidasPlugin.owner());
    asMidasPlugin.shutdown(market);

    emit log("withdrawn assets are");
    assets = ERC20Upgradeable(underlying).balanceOf(market);
    emit log_uint(assets);
  }
}
