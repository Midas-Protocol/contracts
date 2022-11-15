// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";

import { DiamondExtension } from "../midas/DiamondExtension.sol";
import { ComptrollerFirstExtension } from "../compound/ComptrollerFirstExtension.sol";
import { ComptrollerSecondExtension } from "../compound/ComptrollerSecondExtension.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { Unitroller } from "../compound/Unitroller.sol";

contract ExtensionsTest is BaseTest {
  function testExtensionReplace() public fork(BSC_MAINNET) {
    ComptrollerFirstExtension cfe = new ComptrollerFirstExtension();
    ComptrollerSecondExtension cse = new ComptrollerSecondExtension();
    address payable jFiatPoolAddress = payable(0x31d76A64Bc8BbEffb601fac5884372DEF910F044);

    {
      // change the implementation to the new that can add extensions
      Comptroller newComptrollerImplementation = new Comptroller(payable(ap.getAddress("FuseFeeDistributor")));
      Unitroller asUnitroller = Unitroller(jFiatPoolAddress);
      address oldComptrollerImplementation = asUnitroller.comptrollerImplementation();
      // whitelist the upgrade
      FuseFeeDistributor ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
      vm.prank(ffd.owner());
      ffd._editComptrollerImplementationWhitelist(
        asArray(oldComptrollerImplementation),
        asArray(address(newComptrollerImplementation)),
        asArray(true)
      );

      // upgrade to the new comptroller and initialize the extension
      vm.startPrank(asUnitroller.admin());
      {
        asUnitroller._setPendingImplementation(address(newComptrollerImplementation));
        newComptrollerImplementation._become(asUnitroller);
        Comptroller asComptroller = Comptroller(jFiatPoolAddress);
        asComptroller._registerExtension(cfe, DiamondExtension(address(0)));
      }
      vm.stopPrank();
    }

    // replace the extension
    {
      Comptroller asComptroller = Comptroller(jFiatPoolAddress);
      vm.prank(asComptroller.admin());
      asComptroller._registerExtension(cse, cfe);
    }

    // assert that the replacement worked
    ComptrollerSecondExtension asSecondExtension = ComptrollerSecondExtension(jFiatPoolAddress);
    emit log(asSecondExtension.getSecondMarketSymbol());
    assertEq(asSecondExtension.getSecondMarketSymbol(), "fETH-1", "market symbol does not match");
  }
}
