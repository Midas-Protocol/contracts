// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";

import { DiamondExtension } from "../midas/DiamondExtension.sol";
import { ComptrollerFirstExtension } from "../compound/ComptrollerFirstExtension.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { Comptroller, ComptrollerV3Storage } from "../compound/Comptroller.sol";
import { Unitroller } from "../compound/Unitroller.sol";

contract MockComptrollerExtension is DiamondExtension, ComptrollerV3Storage {
  function getFirstMarketSymbol() public view returns (string memory) {
    return allMarkets[0].symbol();
  }

  function _setTransferPaused(bool state) public returns (bool) {
    return false;
  }

  function _setSeizePaused(bool state) public returns (bool) {
    return false;
  }

  // a dummy fn to test if the replacement of extension fns works
  function getSecondMarketSymbol() public view returns (string memory) {
    return allMarkets[1].symbol();
  }

  function _getExtensionFunctions() external view virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 4;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this._setTransferPaused.selector;
    functionSelectors[--fnsCount] = this._setSeizePaused.selector;
    functionSelectors[--fnsCount] = this.getFirstMarketSymbol.selector;
    functionSelectors[--fnsCount] = this.getSecondMarketSymbol.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }
}


contract ExtensionsTest is BaseTest {
  function testExtensionReplace() public fork(BSC_MAINNET) {
    ComptrollerFirstExtension cfe = new ComptrollerFirstExtension();
    MockComptrollerExtension mce = new MockComptrollerExtension();
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
      asComptroller._registerExtension(mce, cfe);
    }

    // assert that the replacement worked
    MockComptrollerExtension asMockExtension = MockComptrollerExtension(jFiatPoolAddress);
    emit log(asMockExtension.getSecondMarketSymbol());
    assertEq(asMockExtension.getSecondMarketSymbol(), "fETH-1", "market symbol does not match");
  }
}
