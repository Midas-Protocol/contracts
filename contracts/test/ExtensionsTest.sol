// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { DiamondExtension, DiamondBase } from "../midas/DiamondExtension.sol";
import { ComptrollerFirstExtension } from "../compound/ComptrollerFirstExtension.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { Comptroller, ComptrollerV3Storage } from "../compound/Comptroller.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { CTokenInterface, CTokenExtensionInterface } from "../compound/CTokenInterfaces.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CTokenFirstExtension } from "../compound/CTokenFirstExtension.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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

contract MockSecondComptrollerExtension is DiamondExtension, ComptrollerV3Storage {
  function getThirdMarketSymbol() public view returns (string memory) {
    return allMarkets[2].symbol();
  }

  function _getExtensionFunctions() external view virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 1;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.getThirdMarketSymbol.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }
}

contract MockThirdComptrollerExtension is DiamondExtension, ComptrollerV3Storage {
  function getFourthMarketSymbol() public view returns (string memory) {
    return allMarkets[3].symbol();
  }

  function _getExtensionFunctions() external view virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 1;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.getFourthMarketSymbol.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }
}

contract ExtensionsTest is BaseTest {
  // ERC1967Upgrade
  bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  address payable internal jFiatPoolAddress = payable(0x31d76A64Bc8BbEffb601fac5884372DEF910F044);
  FuseFeeDistributor internal ffd;
  ComptrollerFirstExtension internal cfe;
  MockComptrollerExtension internal mockExtension;
  MockSecondComptrollerExtension internal second;
  MockThirdComptrollerExtension internal third;
  address internal latestComptrollerImplementation;

  function afterForkSetUp() internal override {
    ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));

    if (block.chainid == BSC_MAINNET) {
      // change the implementation to the new that can add extensions
      Comptroller newComptrollerImplementation = new Comptroller(payable(ap.getAddress("FuseFeeDistributor")));
      latestComptrollerImplementation = address(newComptrollerImplementation);

      Unitroller asUnitroller = Unitroller(jFiatPoolAddress);
      address oldComptrollerImplementation = asUnitroller.comptrollerImplementation();
      // whitelist the upgrade
      vm.prank(ffd.owner());
      ffd._editComptrollerImplementationWhitelist(
        asArray(oldComptrollerImplementation),
        asArray(latestComptrollerImplementation),
        asArray(true)
      );
      // whitelist the new pool creation
      vm.prank(ffd.owner());
      ffd._editComptrollerImplementationWhitelist(
        asArray(address(0)),
        asArray(latestComptrollerImplementation),
        asArray(true)
      );
      // upgrade to the new comptroller
      vm.startPrank(asUnitroller.admin());
      asUnitroller._setPendingImplementation(latestComptrollerImplementation);
      newComptrollerImplementation._become(asUnitroller);
      vm.stopPrank();

      // upgrade the FuseFeeDistributor to include the getCErc20DelegateExtensions fn
      {
        FuseFeeDistributor newImpl = new FuseFeeDistributor();
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(ffd)));
        bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
        address admin = address(uint160(uint256(bytesAtSlot)));
        // emit log_address(admin);
        vm.prank(admin);
        proxy.upgradeTo(address(newImpl));
      }
    }

    cfe = new ComptrollerFirstExtension();
    mockExtension = new MockComptrollerExtension();
    second = new MockSecondComptrollerExtension();
    third = new MockThirdComptrollerExtension();
  }

  function testExtensionReplace() public fork(BSC_MAINNET) {
    // initialize with the first extension
    vm.prank(ffd.owner());
    ffd._registerComptrollerExtension(jFiatPoolAddress, cfe, DiamondExtension(address(0)));

    // replace the first extension with the mock
    vm.prank(ffd.owner());
    ffd._registerComptrollerExtension(jFiatPoolAddress, mockExtension, cfe);

    // assert that the replacement worked
    MockComptrollerExtension asMockExtension = MockComptrollerExtension(jFiatPoolAddress);
    emit log(asMockExtension.getSecondMarketSymbol());
    assertEq(asMockExtension.getSecondMarketSymbol(), "fETH-1", "market symbol does not match");

    // add a second mock extension
    vm.prank(ffd.owner());
    ffd._registerComptrollerExtension(jFiatPoolAddress, second, DiamondExtension(address(0)));

    // add again the third, removing the second
    vm.prank(ffd.owner());
    ffd._registerComptrollerExtension(jFiatPoolAddress, third, second);

    // assert that it worked
    DiamondBase asBase = DiamondBase(jFiatPoolAddress);
    address[] memory currentExtensions = asBase._listExtensions();
    assertEq(currentExtensions.length, 2, "extensions count does not match");
    assertEq(currentExtensions[0], address(mockExtension), "!first");
    assertEq(currentExtensions[1], address(third), "!second");
  }

  function testNewPoolExtensions() public fork(BSC_MAINNET) {
    FusePoolDirectory fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));

    // deploy a pool that will not get any extensions automatically
    {
      (, address poolAddress) = fpd.deployPool(
        "just-a-test",
        latestComptrollerImplementation,
        abi.encode(payable(address(ffd))),
        false,
        0.1e18,
        1.1e18,
        ap.getAddress("MasterPriceOracle")
      );

      address[] memory initExtensionsBefore = DiamondBase(payable(poolAddress))._listExtensions();
      assertEq(initExtensionsBefore.length, 0, "remove this if the ffd config is set up");
    }

    // configure the FFD so that the extension is automatically added on the pool creation
    DiamondExtension[] memory comptrollerExtensions = new DiamondExtension[](1);
    comptrollerExtensions[0] = cfe;
    vm.prank(ffd.owner());
    ffd._setComptrollerExtensions(latestComptrollerImplementation, comptrollerExtensions);

    // deploy a pool that will have an extension registered automatically
    {
      (, address poolAddress) = fpd.deployPool(
        "just-a-test2",
        latestComptrollerImplementation,
        abi.encode(payable(address(ffd))),
        false,
        0.1e18,
        1.1e18,
        ap.getAddress("MasterPriceOracle")
      );

      address[] memory initExtensionsAfter = DiamondBase(payable(poolAddress))._listExtensions();
      assertEq(initExtensionsAfter.length, 1, "remove this if the ffd config is set up");
      assertEq(initExtensionsAfter[0], address(cfe), "first extension is not the CFE");
    }
  }

  function testExistingCTokenExtensionUpgrade() public fork(BSC_MAINNET) {
    Comptroller asComptroller = Comptroller(jFiatPoolAddress);
    CTokenInterface[] memory allMarkets = asComptroller.getAllMarkets();

    CTokenInterface firstMarket = allMarkets[0];
    CErc20Delegate asDelegate = CErc20Delegate(address(firstMarket));
    emit log(asDelegate.contractType());

    address implBefore = asDelegate.implementation();
    emit log("implementation before");
    emit log_address(implBefore);

    CErc20Delegate newImpl = new CErc20Delegate();

    // whitelist the upgrade
    vm.prank(ffd.owner());
    ffd._editCErc20DelegateWhitelist(asArray(implBefore), asArray(address(newImpl)), asArray(false), asArray(true));

    // set the new ctoken delegate as the latest
    vm.prank(ffd.owner());
    ffd._setLatestCErc20Delegate(implBefore, address(newImpl), false, "");

    // add the extension to the auto upgrade config
    DiamondExtension[] memory cErc20DelegateExtensions = new DiamondExtension[](1);
    cErc20DelegateExtensions[0] = new CTokenFirstExtension();
    vm.prank(ffd.owner());
    ffd._setCErc20DelegateExtensions(address(newImpl), cErc20DelegateExtensions);

    // turn auto impl on
    vm.prank(asComptroller.admin());
    asComptroller._toggleAutoImplementations(true);

    // auto upgrade
    CTokenExtensionInterface(address(firstMarket)).accrueInterest();
    emit log("new implementation");
    emit log_address(asDelegate.implementation());

    // check if the extension was added
    address[] memory extensions = asDelegate._listExtensions();
    assertEq(extensions.length, 1, "the first extension should be added");
    assertEq(extensions[0], address(cErc20DelegateExtensions[0]), "the first extension should be the only extension");
  }
}
