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
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { CErc20PluginRewardsDelegate } from "../compound/CErc20PluginRewardsDelegate.sol";

import { CTokenFirstExtension } from "../compound/CTokenFirstExtension.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { ICToken } from "../external/compound/ICToken.sol";

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
  address payable internal jFiatPoolAddress = payable(0x31d76A64Bc8BbEffb601fac5884372DEF910F044);
  FuseFeeDistributor internal ffd;
  ComptrollerFirstExtension internal cfe;
  CTokenFirstExtension newCTokenExtension;
  MockComptrollerExtension internal mockExtension;
  MockSecondComptrollerExtension internal second;
  MockThirdComptrollerExtension internal third;
  address internal latestComptrollerImplementation;

  function afterForkSetUp() internal override {
    ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));

    cfe = new ComptrollerFirstExtension();
    newCTokenExtension = new CTokenFirstExtension();
    mockExtension = new MockComptrollerExtension();
    second = new MockSecondComptrollerExtension();
    third = new MockThirdComptrollerExtension();

    if (block.chainid == BSC_MAINNET) {
      // change the implementation to the new that can add extensions
      Comptroller newComptrollerImplementation = new Comptroller(payable(ap.getAddress("FuseFeeDistributor")));
      latestComptrollerImplementation = address(newComptrollerImplementation);

      Unitroller asUnitroller = Unitroller(jFiatPoolAddress);
      address oldComptrollerImplementation = asUnitroller.comptrollerImplementation();

      // whitelist the upgrade
      vm.startPrank(ffd.owner());
      ffd._editComptrollerImplementationWhitelist(
        asArray(oldComptrollerImplementation),
        asArray(latestComptrollerImplementation),
        asArray(true)
      );
      // whitelist the new pool creation
      ffd._editComptrollerImplementationWhitelist(
        asArray(address(0)),
        asArray(latestComptrollerImplementation),
        asArray(true)
      );
      DiamondExtension[] memory extensions = new DiamondExtension[](1);
      extensions[0] = cfe;
      ffd._setComptrollerExtensions(latestComptrollerImplementation, extensions);
      vm.stopPrank();

      // upgrade to the new comptroller
      vm.startPrank(asUnitroller.admin());
      asUnitroller._setPendingImplementation(latestComptrollerImplementation);
      newComptrollerImplementation._become(asUnitroller);
      vm.stopPrank();
    }
  }

  function testExtensionReplace() public debuggingOnly fork(BSC_MAINNET) {
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

  function testMulticallMarket() public fork(BSC_MAINNET) {
    uint8 random = uint8(block.timestamp % 256);
    FusePoolDirectory fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();

    ComptrollerFirstExtension somePool = ComptrollerFirstExtension(pools[random % pools.length].comptroller);
    CTokenInterface[] memory markets = somePool.getAllMarkets();

    CTokenInterface someMarket = markets[random % markets.length];
    CErc20PluginDelegate asDelegate = CErc20PluginDelegate(address(someMarket));
    CTokenExtensionInterface asExtension = asDelegate.asCTokenExtensionInterface();

    emit log("pool");
    emit log_address(address(somePool));
    emit log("market");
    emit log_address(address(someMarket));

    vm.roll(block.number + 1);

    bytes memory blockNumberBeforeCall = abi.encodeWithSelector(asDelegate.accrualBlockNumber.selector);
    bytes memory accrueInterestCall = abi.encodeWithSelector(asExtension.accrueInterest.selector);
    bytes memory blockNumberAfterCall = abi.encodeWithSelector(asDelegate.accrualBlockNumber.selector);
    bytes[] memory results = asDelegate.multicall(
      asArray(blockNumberBeforeCall, accrueInterestCall, blockNumberAfterCall)
    );
    uint256 blockNumberBefore = abi.decode(results[0], (uint256));
    uint256 blockNumberAfter = abi.decode(results[2], (uint256));

    assertGt(blockNumberAfter, blockNumberBefore, "did not accrue?");
  }

  function testExistingCTokenExtensionUpgrade() public fork(BSC_MAINNET) {
    uint8 random = uint8(block.timestamp % 256);
    FusePoolDirectory fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();

    ComptrollerFirstExtension somePool = ComptrollerFirstExtension(pools[random % pools.length].comptroller);
    CTokenInterface[] memory markets = somePool.getAllMarkets();

    CTokenInterface someMarket = markets[random % markets.length];
    CErc20PluginDelegate asDelegate = CErc20PluginDelegate(address(someMarket));

    emit log("pool");
    emit log_address(address(somePool));
    emit log("market");
    emit log_address(address(someMarket));

    try this._testExistingCTokenExtensionUpgrade(asDelegate) {} catch Error(string memory reason) {
      emit log("at random");
      emit log_uint(random);

      address plugin = address(asDelegate.plugin());
      emit log("plugin");
      emit log_address(plugin);

      address latestPlugin = ffd.latestPluginImplementation(plugin);
      emit log("latest plugin impl");
      emit log_address(latestPlugin);

      revert(reason);
    }
  }

  function _testExistingCTokenExtensionUpgrade(CErc20Delegate asDelegate) public {
    uint256 totalSupplyBefore = asDelegate.totalSupply();
    if (totalSupplyBefore == 0) return; // total supply should be non-zero

    _upgradeExistingCTokenExtension(asDelegate);

    // check if the extension was added
    address[] memory extensions = asDelegate._listExtensions();
    assertEq(extensions.length, 1, "the first extension should be added");
    assertEq(extensions[0], address(newCTokenExtension), "the first extension should be the only extension");

    // check if the storage is read from the same place
    uint256 totalSupplyAfter = asDelegate.totalSupply();
    assertGt(totalSupplyAfter, 0, "total supply should be non-zero");
    assertEq(totalSupplyAfter, totalSupplyBefore, "total supply should be the same");
  }

  function _upgradeExistingCTokenExtension(CErc20Delegate asDelegate) internal {
    address implBefore = asDelegate.implementation();
    emit log("implementation before");
    emit log_address(implBefore);

    Comptroller pool = Comptroller(address(asDelegate.comptroller()));

    CErc20Delegate newImpl;
    if (compareStrings("CErc20Delegate", asDelegate.contractType())) {
      newImpl = new CErc20Delegate();
    } else {
      newImpl = new CErc20PluginRewardsDelegate();
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

    // turn auto impl on
    vm.prank(pool.admin());
    pool._toggleAutoImplementations(true);

    // auto upgrade
    CTokenExtensionInterface(address(asDelegate)).accrueInterest();
    emit log("new implementation");
    emit log_address(asDelegate.implementation());
  }

  function testBscComptrollerExtensions() public debuggingOnly fork(BSC_MAINNET) {
    _testComptrollersExtensions();
  }

  function testPolygonComptrollerExtensions() public debuggingOnly fork(POLYGON_MAINNET) {
    _testComptrollersExtensions();
  }

  function testMoonbeamComptrollerExtensions() public debuggingOnly fork(MOONBEAM_MAINNET) {
    _testComptrollersExtensions();
  }

  function testChapelComptrollerExtensions() public debuggingOnly fork(BSC_CHAPEL) {
    _testComptrollersExtensions();
  }

  function testArbitrumComptrollerExtensions() public debuggingOnly fork(ARBITRUM_ONE) {
    _testComptrollersExtensions();
  }

  function testFantomComptrollerExtensions() public debuggingOnly fork(FANTOM_OPERA) {
    _testComptrollersExtensions();
  }

  function _testComptrollersExtensions() internal {
    FusePoolDirectory fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();

    for (uint8 i = 0; i < pools.length; i++) {
      address payable asPayable = payable(pools[i].comptroller);
      DiamondBase asBase = DiamondBase(asPayable);
      address[] memory extensions = asBase._listExtensions();
      assertEq(extensions.length, 1, "each pool should have the first extension");
    }
  }
}
