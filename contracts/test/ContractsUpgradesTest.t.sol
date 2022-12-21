// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { ComptrollerFirstExtension, DiamondExtension } from "../compound/ComptrollerFirstExtension.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CToken } from "../compound/CToken.sol";
import { CTokenInterface } from "../compound/CTokenInterfaces.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { DiamondExtension, DiamondBase } from "../midas/DiamondExtension.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract ContractsUpgradesTest is BaseTest {
  function testFusePoolDirectoryUpgrade() public fork(BSC_MAINNET) {
    address contractToTest = ap.getAddress("FusePoolDirectory"); // FusePoolDirectory proxy

    // before upgrade
    FusePoolDirectory oldImpl = FusePoolDirectory(contractToTest);
    (, FusePoolDirectory.FusePool[] memory poolsBefore) = oldImpl.getActivePools();
    address ownerBefore = oldImpl.owner();
    emit log_address(ownerBefore);

    uint256 lenBefore = poolsBefore.length;
    emit log_uint(lenBefore);

    // upgrade
    {
      FusePoolDirectory newImpl = new FusePoolDirectory();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(contractToTest));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    // after upgrade
    FusePoolDirectory newImpl = FusePoolDirectory(contractToTest);
    address ownerAfter = newImpl.owner();
    emit log_address(ownerAfter);

    (, FusePoolDirectory.FusePool[] memory poolsAfter) = oldImpl.getActivePools();
    uint256 lenAfter = poolsAfter.length;
    emit log_uint(poolsAfter.length);

    assertEq(lenBefore, lenAfter, "pools count does not match");
    assertEq(ownerBefore, ownerAfter, "owner mismatch");
  }

  function testFuseFeeDistributorUpgrade() public fork(BSC_MAINNET) {
    address oldCercDelegate = 0x94C50805bC16737ead84e25Cd5Aa956bCE04BBDF;

    // before upgrade
    FuseFeeDistributor ffdProxy = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
    uint256 marketsCounterBefore = ffdProxy.marketsCounter();
    address ownerBefore = ffdProxy.owner();

    (address latestCErc20DelegateBefore, , ) = ffdProxy.latestCErc20Delegate(oldCercDelegate);
    //    bool whitelistedBefore = ffdProxy.cErc20DelegateWhitelist(oldCercDelegate, latestCErc20DelegateBefore, false);

    emit log_uint(marketsCounterBefore);
    emit log_address(ownerBefore);
    //    if (whitelistedBefore) emit log("whitelisted before");
    //    else emit log("should be whitelisted");

    // upgrade
    {
      FuseFeeDistributor newImpl = new FuseFeeDistributor();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(ffdProxy)));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    // after upgrade
    FuseFeeDistributor ffd = FuseFeeDistributor(payable(address(ffdProxy)));

    uint256 marketsCounterAfter = ffd.marketsCounter();
    address ownerAfter = ffd.owner();
    (address latestCErc20DelegateAfter, bool allowResignAfter, bytes memory becomeImplementationDataAfter) = ffd
      .latestCErc20Delegate(oldCercDelegate);
    //    bool whitelistedAfter = ffd.cErc20DelegateWhitelist(oldCercDelegate, latestCErc20DelegateAfter, false);

    emit log_uint(marketsCounterAfter);
    emit log_address(ownerAfter);
    //    if (whitelistedAfter) emit log("whitelisted After");
    //    else emit log("should be whitelisted");

    assertEq(latestCErc20DelegateBefore, latestCErc20DelegateAfter, "latest delegates do not match");
    assertEq(marketsCounterBefore, marketsCounterAfter, "markets counter does not match");
    //    assertEq(whitelistedBefore, whitelistedAfter, "whitelisted status does not match");

    assertEq(ownerBefore, ownerAfter, "owner mismatch");
  }

  function testFlywheelReinitializeBsc() public debuggingOnly fork(BSC_MAINNET) {
    _testFlywheelReinitialize();
  }

  function testFlywheelReinitializePolygon() public debuggingOnly fork(POLYGON_MAINNET) {
    _testFlywheelReinitialize();
  }

  function testFlywheelReinitializeMoonbeam() public debuggingOnly fork(MOONBEAM_MAINNET) {
    _testFlywheelReinitialize();
  }

  function _testFlywheelReinitialize() internal {
    FusePoolDirectory fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);
      address[] memory flywheels = pool.getRewardsDistributors();
      for (uint8 j = 0; j < flywheels.length; j++) {
        MidasFlywheelCore flywheel = MidasFlywheelCore(flywheels[j]);

        // upgrade
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(flywheels[j]));
        bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
        address admin = address(uint160(uint256(bytesAtSlot)));

        if (admin != address(0)) {
          MidasFlywheelCore newImpl = new MidasFlywheelCore();
          vm.prank(admin);
          proxy.upgradeTo(address(newImpl));

          vm.prank(flywheel.owner());
          // flywheel.reinitialize();
        }
      }
    }
  }

  function testMarketsLatestImplementationsBsc() public fork(BSC_MAINNET) {
    _testMarketsLatestImplementations();
  }

  function testMarketsLatestImplementationsPolygon() public fork(POLYGON_MAINNET) {
    _testMarketsLatestImplementations();
  }

  function testMarketsLatestImplementationsMoonbeam() public fork(MOONBEAM_MAINNET) {
    _testMarketsLatestImplementations();
  }

  function _testMarketsLatestImplementations() internal {
    FuseFeeDistributor ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
    FusePoolDirectory fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
    (, FusePoolDirectory.FusePool[] memory pools) = fpd.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);
      ICToken[] memory markets = pool.getAllMarkets();
      for (uint8 j = 0; j < markets.length; j++) {
        CErc20Delegate market = CErc20Delegate(address(markets[j]));

        address currentImpl = market.implementation();
        (address upgradeToImpl, , ) = ffd.latestCErc20Delegate(currentImpl);

        if (currentImpl != upgradeToImpl) emit log_address(address(market));
        assertEq(currentImpl, upgradeToImpl, "market needs to be upgraded");

        DiamondBase asBase = DiamondBase(address(markets[j]));
        try asBase._listExtensions() returns (address[] memory extensions) {
          assertEq(extensions.length, 1, "market is missing the first extension");
        } catch {
          emit log("market that is not yet upgraded to the extensions upgrade");
          emit log_address(address(market));
          emit log("implementation");
          emit log_address(currentImpl);
          emit log("pool");
          emit log_address(pools[i].comptroller);
          emit log("");
        }
      }
    }
  }
}
