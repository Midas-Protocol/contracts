pragma solidity ^0.8.0;

import { CErc20 } from "../compound/CToken.sol";
import { IComptroller } from "../compound/ComptrollerInterface.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { FeeDistributor } from "../FeeDistributor.sol";
import { PoolDirectory } from "../PoolDirectory.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";
import { IERC4626 } from "../compound/IERC4626.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract LatestImplementationWhitelisted is BaseTest {
  FeeDistributor ionicAdmin;
  PoolDirectory poolDirectory;

  address[] implementationsSet;
  address[] pluginsSet;

  function testBscImplementations() public fork(BSC_MAINNET) {
    testPoolImplementations();
    testMarketImplementations();
    testPluginImplementations();
  }

  function testPolygonImplementations() public fork(POLYGON_MAINNET) {
    testPoolImplementations();
    testMarketImplementations();
    testPluginImplementations();
  }

  function afterForkSetUp() internal override {
    poolDirectory = PoolDirectory(ap.getAddress("PoolDirectory"));
    ionicAdmin = FeeDistributor(payable(ap.getAddress("FeeDistributor")));
  }

  function testPoolImplementations() internal {
    (, PoolDirectory.Pool[] memory pools) = poolDirectory.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller comptroller = IComptroller(payable(pools[i].comptroller));
      address implementation = comptroller.comptrollerImplementation();

      bool added = false;
      for (uint8 k = 0; k < implementationsSet.length; k++) {
        if (implementationsSet[k] == implementation) {
          added = true;
        }
      }

      if (!added) implementationsSet.push(implementation);
    }

    emit log("listing the set");
    for (uint8 k = 0; k < implementationsSet.length; k++) {
      emit log_address(implementationsSet[k]);

      address latestImpl = ionicAdmin.latestComptrollerImplementation(implementationsSet[k]);
      assertTrue(implementationsSet[k] == latestImpl, "some pool is not upgraded the latest impl");
    }
  }

  function testMarketImplementations() internal {
    (, PoolDirectory.Pool[] memory pools) = poolDirectory.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller comptroller = IComptroller(payable(pools[i].comptroller));
      ICErc20[] memory markets = comptroller.getAllMarkets();
      for (uint8 j = 0; j < markets.length; j++) {
        ICErc20 market = markets[j];
        address implementation = market.implementation();

        bool added = false;
        for (uint8 k = 0; k < implementationsSet.length; k++) {
          if (implementationsSet[k] == implementation) {
            added = true;
          }
        }

        if (!added) implementationsSet.push(implementation);
      }
    }

    emit log("listing the set");
    for (uint8 k = 0; k < implementationsSet.length; k++) {
      emit log_address(implementationsSet[k]);
      (address latestCErc20Delegate, bytes memory becomeImplementationData) = ionicAdmin.latestCErc20Delegate(
        CErc20Delegate(implementationsSet[k]).delegateType()
      );

      assertTrue(implementationsSet[k] == latestCErc20Delegate, "some markets need to be upgraded");
    }
  }

  function testPluginImplementations() internal {
    (, PoolDirectory.Pool[] memory pools) = poolDirectory.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller comptroller = IComptroller(payable(pools[i].comptroller));
      ICErc20[] memory markets = comptroller.getAllMarkets();
      for (uint8 j = 0; j < markets.length; j++) {
        CErc20PluginDelegate delegate = CErc20PluginDelegate(address(markets[j]));

        address plugin;
        try delegate.plugin() returns (IERC4626 _plugin) {
          plugin = address(_plugin);
        } catch {
          continue;
        }

        bool added = false;
        for (uint8 k = 0; k < pluginsSet.length; k++) {
          if (pluginsSet[k] == plugin) {
            added = true;
          }
        }

        if (!added) pluginsSet.push(plugin);
      }
    }

    emit log("listing the set");
    for (uint8 k = 0; k < pluginsSet.length; k++) {
      address latestPluginImpl = ionicAdmin.latestPluginImplementation(pluginsSet[k]);

      emit log_address(pluginsSet[k]);

      assertTrue(pluginsSet[k] == latestPluginImpl, "some plugin is not upgraded to the latest impl");
    }
  }
}
