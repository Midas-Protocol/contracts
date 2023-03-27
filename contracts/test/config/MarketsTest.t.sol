// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./BaseTest.t.sol";
import { FuseFeeDistributor } from "../../FuseFeeDistributor.sol";
import { CErc20Delegate } from "../../compound/CErc20Delegate.sol";
import { CErc20PluginRewardsDelegate } from "../../compound/CErc20PluginRewardsDelegate.sol";
import { DiamondExtension } from "../../midas/DiamondExtension.sol";
import { CTokenFirstExtension } from "../../compound/CTokenFirstExtension.sol";

contract MarketsTest is BaseTest {
  FuseFeeDistributor internal ffd;
  CErc20Delegate internal cErc20Delegate;
  CErc20PluginRewardsDelegate internal cErc20PluginRewardsDelegate;
  CTokenFirstExtension internal newCTokenExtension;

  function afterForkSetUp() internal virtual override {
    ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
    cErc20Delegate = new CErc20Delegate();
    cErc20PluginRewardsDelegate = new CErc20PluginRewardsDelegate();
    newCTokenExtension = new CTokenFirstExtension();
  }

  function _prepareCTokenUpgrade(CErc20Delegate market) internal returns (address) {
    address implBefore = market.implementation();
    //emit log("implementation before");
    //emit log_address(implBefore);

    CErc20Delegate newImpl;
    if (compareStrings("CErc20Delegate", market.contractType())) {
      newImpl = cErc20Delegate;
    } else {
      newImpl = cErc20PluginRewardsDelegate;
    }

    // whitelist the upgrade
    vm.prank(ffd.owner());
    ffd._editCErc20DelegateWhitelist(asArray(implBefore), asArray(address(newImpl)), asArray(false), asArray(true));

    // set the new ctoken delegate as the latest
    vm.prank(ffd.owner());
    ffd._setLatestCErc20Delegate(implBefore, address(newImpl), false, abi.encode(address(0)));

    // add the extension to the auto upgrade config
    DiamondExtension[] memory cErc20DelegateExtensions = new DiamondExtension[](1);
    cErc20DelegateExtensions[0] = newCTokenExtension;
    vm.prank(ffd.owner());
    ffd._setCErc20DelegateExtensions(address(newImpl), cErc20DelegateExtensions);

    return address(newImpl);
  }

  function _upgradeExistingCTokenExtension(CErc20Delegate asDelegate) internal {
    address newDelegate = _prepareCTokenUpgrade(asDelegate);

    bytes memory becomeImplData = (address(newDelegate) == address(cErc20Delegate))
      ? bytes("")
      : abi.encode(address(0));
    vm.prank(asDelegate.fuseAdmin());
    asDelegate._setImplementationSafe(newDelegate, false, becomeImplData);
  }
}