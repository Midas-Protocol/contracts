// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { FeeDistributor } from "../FeeDistributor.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { DiamondExtension } from "../ionic/DiamondExtension.sol";
import { ComptrollerFirstExtension } from "../compound/ComptrollerFirstExtension.sol";
import { CTokenFirstExtension } from "../compound/CTokenFirstExtension.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { CErc20PluginRewardsDelegate } from "../compound/CErc20PluginRewardsDelegate.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract UpgradesBaseTest is BaseTest {
  FeeDistributor internal ffd;
  ComptrollerFirstExtension internal poolExt;
  CTokenFirstExtension internal marketExt;

  function afterForkSetUp() internal virtual override {
    ffd = FeeDistributor(payable(ap.getAddress("FeeDistributor")));
    poolExt = new ComptrollerFirstExtension();
    marketExt = new CTokenFirstExtension();
  }

  function _upgradePoolWithExtension(Unitroller asUnitroller) internal {
    address oldComptrollerImplementation = asUnitroller.comptrollerImplementation();

    // instantiate the new implementation
    Comptroller newComptrollerImplementation = new Comptroller(payable(address(ffd)));
    address comptrollerImplementationAddress = address(newComptrollerImplementation);
    // add the extension to the auto upgrade config
    DiamondExtension[] memory extensions = new DiamondExtension[](1);
    extensions[0] = poolExt;
    ffd._setComptrollerExtensions(comptrollerImplementationAddress, extensions);
    vm.stopPrank();

    // upgrade to the new comptroller
    vm.startPrank(asUnitroller.admin());
    asUnitroller._registerExtension(comptrollerImplementationAddress, asUnitroller.comptrollerImplementation());
    vm.stopPrank();
  }

  function _upgradeMarketWithExtension(CErc20Delegate market) internal {
    address implBefore = market.implementation();

    // instantiate the new implementation
    CErc20Delegate newImpl;
    bytes memory becomeImplData = "";
    if (compareStrings("CErc20Delegate", market.contractType())) {
      newImpl = new CErc20Delegate();
    } else if (compareStrings("CErc20PluginDelegate", market.contractType())) {
      newImpl = new CErc20PluginDelegate();
      becomeImplData = abi.encode(address(0));
    } else {
      newImpl = new CErc20PluginRewardsDelegate();
      becomeImplData = abi.encode(address(0));
    }

    // add the extension to the auto upgrade config
    DiamondExtension[] memory cErc20DelegateExtensions = new DiamondExtension[](1);
    cErc20DelegateExtensions[0] = marketExt;
    vm.prank(ffd.owner());
    ffd._setCErc20DelegateExtensions(address(newImpl), cErc20DelegateExtensions);

    // upgrade to the new delegate
    vm.prank(address(ffd));
    market._setImplementationSafe(address(newImpl), false, becomeImplData);
  }
}
