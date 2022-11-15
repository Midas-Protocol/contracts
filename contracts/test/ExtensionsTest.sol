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
  // ERC1967Upgrade
  bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  function testExtensionReplace() public fork(BSC_MAINNET) {
    ComptrollerFirstExtension cfe = new ComptrollerFirstExtension();
    MockComptrollerExtension mce = new MockComptrollerExtension();
    address payable jFiatPoolAddress = payable(0x31d76A64Bc8BbEffb601fac5884372DEF910F044);
    FuseFeeDistributor ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));

    // change the implementation to the new that can add extensions
    Comptroller newComptrollerImplementation = new Comptroller(payable(ap.getAddress("FuseFeeDistributor")));
    Unitroller asUnitroller = Unitroller(jFiatPoolAddress);
    address oldComptrollerImplementation = asUnitroller.comptrollerImplementation();
    // whitelist the upgrade

    // upgrade the FuseFeeDistributor to include the _registerComptrollerExtension fn
    {
      FuseFeeDistributor newImpl = new FuseFeeDistributor();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(ffd)));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      // emit log_address(admin);
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    // whitelist the new comptroller implementation
    vm.prank(ffd.owner());
    ffd._editComptrollerImplementationWhitelist(
      asArray(oldComptrollerImplementation),
      asArray(address(newComptrollerImplementation)),
      asArray(true)
    );

    // upgrade to the new comptroller and initialize the extension
    vm.startPrank(asUnitroller.admin());
    asUnitroller._setPendingImplementation(address(newComptrollerImplementation));
    newComptrollerImplementation._become(asUnitroller);
    vm.stopPrank();
    vm.prank(ffd.owner());
    ffd._registerComptrollerExtension(jFiatPoolAddress, cfe, DiamondExtension(address(0)));

    // replace the cfe extension with mce
    vm.prank(ffd.owner());
    ffd._registerComptrollerExtension(jFiatPoolAddress, mce, cfe);

    // assert that the replacement worked
    MockComptrollerExtension asMockExtension = MockComptrollerExtension(jFiatPoolAddress);
    emit log(asMockExtension.getSecondMarketSymbol());
    assertEq(asMockExtension.getSecondMarketSymbol(), "fETH-1", "market symbol does not match");
  }
}
