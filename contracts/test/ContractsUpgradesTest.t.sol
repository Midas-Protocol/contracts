// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { FeeDistributor } from "../FeeDistributor.sol";
import { PoolDirectory } from "../PoolDirectory.sol";
import { ComptrollerFirstExtension, DiamondExtension } from "../compound/ComptrollerFirstExtension.sol";
import { IonicFlywheelCore } from "../ionic/strategies/flywheel/IonicFlywheelCore.sol";
import { IonicFlywheel } from "../ionic/strategies/flywheel/IonicFlywheel.sol";
import { IComptroller } from "../compound/ComptrollerInterface.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CToken } from "../compound/CToken.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { DiamondExtension, DiamondBase } from "../ionic/DiamondExtension.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract ContractsUpgradesTest is BaseTest {
  function testFusePoolDirectoryUpgrade() public fork(BSC_MAINNET) {
    address contractToTest = ap.getAddress("PoolDirectory"); // PoolDirectory proxy

    // before upgrade
    PoolDirectory fpdBefore = PoolDirectory(contractToTest);
    PoolDirectory.Pool[] memory poolsBefore = fpdBefore.getAllPools();
    address ownerBefore = fpdBefore.owner();
    emit log_address(ownerBefore);

    uint256 lenBefore = poolsBefore.length;
    emit log_uint(lenBefore);

    // upgrade
    {
      PoolDirectory newImpl = new PoolDirectory();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(contractToTest));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    // after upgrade
    PoolDirectory fpd = PoolDirectory(contractToTest);
    address ownerAfter = fpd.owner();
    emit log_address(ownerAfter);

    (, PoolDirectory.Pool[] memory poolsAfter) = fpd.getActivePools();
    uint256 lenAfter = poolsAfter.length;
    emit log_uint(poolsAfter.length);

    assertEq(lenBefore, lenAfter, "pools count does not match");
    assertEq(ownerBefore, ownerAfter, "owner mismatch");
  }

  function testFeeDistributorUpgrade() public fork(BSC_MAINNET) {
    address oldCercDelegate = 0x94C50805bC16737ead84e25Cd5Aa956bCE04BBDF;

    // before upgrade
    FeeDistributor ffdProxy = FeeDistributor(payable(ap.getAddress("FeeDistributor")));
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
      FeeDistributor newImpl = new FeeDistributor();
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(ffdProxy)));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      vm.prank(admin);
      proxy.upgradeTo(address(newImpl));
    }

    // after upgrade
    FeeDistributor ffd = FeeDistributor(payable(address(ffdProxy)));

    uint256 marketsCounterAfter = ffd.marketsCounter();
    address ownerAfter = ffd.owner();
    (address latestCErc20DelegateAfter, , ) = ffd.latestCErc20Delegate(oldCercDelegate);
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

  function testMarketsLatestImplementationsChapel() public fork(BSC_CHAPEL) {
    _testMarketsLatestImplementations();
  }

  function testMarketsLatestImplementationsBsc() public fork(BSC_MAINNET) {
    _testMarketsLatestImplementations();
  }

  function testMarketsLatestImplementationsPolygon() public fork(POLYGON_MAINNET) {
    _testMarketsLatestImplementations();
  }

  function testMarketsLatestImplementationsArbitrum() public fork(ARBITRUM_ONE) {
    _testMarketsLatestImplementations();
  }

  function testMarketsLatestImplementationsEth() public fork(ETHEREUM_MAINNET) {
    _testMarketsLatestImplementations();
  }

  function _testMarketsLatestImplementations() internal {
    FeeDistributor ffd = FeeDistributor(payable(ap.getAddress("FeeDistributor")));
    PoolDirectory fpd = PoolDirectory(ap.getAddress("PoolDirectory"));

    if (address(fpd) != address(0)) {
      (, PoolDirectory.Pool[] memory pools) = fpd.getActivePools();

      for (uint8 i = 0; i < pools.length; i++) {
        IComptroller pool = IComptroller(pools[i].comptroller);
        ICErc20[] memory markets = pool.getAllMarkets();
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

  function testPauseGuardiansBsc() public debuggingOnly fork(BSC_MAINNET) {
    _testPauseGuardians();
  }

  function testPauseGuardiansPolygon() public debuggingOnly fork(POLYGON_MAINNET) {
    _testPauseGuardians();
  }

  function _testPauseGuardians() internal {
    PoolDirectory fpd = PoolDirectory(ap.getAddress("PoolDirectory"));
    address deployer = ap.getAddress("deployer");

    (, PoolDirectory.Pool[] memory pools) = fpd.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);
      address pauseGuardian = pool.pauseGuardian();
      if (pauseGuardian != address(0) && pauseGuardian != deployer) {
        emit log_named_address("pool", address(pool));
        emit log_named_address("unknown pause guardian", pauseGuardian);
        emit log("");
      }
    }
  }
}
