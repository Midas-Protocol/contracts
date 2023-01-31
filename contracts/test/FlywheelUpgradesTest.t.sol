// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { MidasReplacingFlywheel } from "../midas/strategies/flywheel/MidasReplacingFlywheel.sol";
import { ReplacingFlywheelDynamicRewards } from "../midas/strategies/flywheel/rewards/ReplacingFlywheelDynamicRewards.sol";
import { MidasFlywheelLensRouter } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";
import { CErc20PluginRewardsDelegate } from "../compound/CErc20PluginRewardsDelegate.sol";
import { ComptrollerFirstExtension } from "../compound/ComptrollerFirstExtension.sol";
import { CTokenInterface } from "../compound/CTokenInterfaces.sol";
import { Comptroller } from "../compound/Comptroller.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";

contract FlywheelUpgradesTest is BaseTest {
  FusePoolDirectory internal fpd;

  function afterForkSetUp() internal override {
    fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
  }

  function testFlywheelUpgradeBsc() public fork(BSC_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradePolygon() public fork(POLYGON_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradeMoonbeam() public fork(MOONBEAM_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradeEvmos() public fork(EVMOS_MAINNET) {
    _testFlywheelUpgrade();
  }

  function _testFlywheelUpgrade() internal {
    MidasFlywheelCore newImpl = new MidasFlywheelCore();

    (, FusePoolDirectory.FusePool[] memory pools) = fpd.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);

      ICToken[] memory markets = pool.getAllMarkets();

      address[] memory flywheels = pool.getRewardsDistributors();
      if (flywheels.length > 0) {
        emit log("");
        emit log_named_address("pool", address(pool));
      }
      for (uint8 j = 0; j < flywheels.length; j++) {
        MidasFlywheelCore flywheel = MidasFlywheelCore(flywheels[j]);

        // upgrade
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(flywheels[j]));
        bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
        address admin = address(uint160(uint256(bytesAtSlot)));

        if (admin != address(0)) {
          //vm.prank(admin);
          //proxy.upgradeTo(address(newImpl));
          //emit log_named_address("upgradable flywheel", address(flywheel));

          bool anyStrategyHasPositiveIndex = false;

          for (uint8 k = 0; k < markets.length; k++) {
            ERC20 strategy = ERC20(address(markets[k]));
            (uint224 index, uint32 ts) = flywheel.strategyState(strategy);
            if (index > 0) {
              anyStrategyHasPositiveIndex = true;
              break;
            }
          }

          if (!anyStrategyHasPositiveIndex) {
            emit log_named_address("all zero index strategies flywheel", address(flywheel));
            //assertTrue(anyStrategyHasPositiveIndex, "!flywheel has no strategies added or is broken");
          }
        } else {
          emit log_named_address("not upgradable flywheel", address(flywheel));
          assertTrue(false, "flywheel proxy admin 0");
        }
      }
    }
  }

  function testUsdcParFlywheelAllowance() public debuggingOnly fork(POLYGON_MAINNET) {
    address usdcParMarket = 0xa5A14c3814d358230a56e8f011B8fc97A508E890;
    address flywheelAddress = 0x5fF63E442AC4724EC342f4a3d26924233832EcBB;

    ERC20 strategy = ERC20(usdcParMarket);
    MidasFlywheelCore flywheel = MidasFlywheelCore(flywheelAddress);
    (uint224 index, ) = MidasFlywheelCore(flywheelAddress).strategyState(strategy);
    ERC20 rewToken = flywheel.rewardToken();
    if (index > 0) {
      uint256 allowance = rewToken.allowance(usdcParMarket, flywheelAddress);
      emit log_named_address("flywheel", flywheelAddress);
      emit log_named_uint("should have positive allowance", allowance);
    }
  }

  function testPolygonFlywheelAllowance() public debuggingOnly fork(POLYGON_MAINNET) {
    _testAllMarketsAllowance();
  }

  function testBscFlywheelAllowance() public debuggingOnly fork(BSC_MAINNET) {
    _testAllMarketsAllowance();
  }

  function _testAllMarketsAllowance() internal {
    (, FusePoolDirectory.FusePool[] memory pools) = fpd.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      _testMarketsAllowance(pools[i].comptroller);
    }
  }

  function _testMarketsAllowance(address poolAddress) internal {
    ComptrollerFirstExtension poolExt = ComptrollerFirstExtension(poolAddress);
    address[] memory fws = poolExt.getRewardsDistributors();

    CTokenInterface[] memory markets = poolExt.getAllMarkets();

    for (uint8 j = 0; j < markets.length; j++) {
      for (uint8 i = 0; i < fws.length; i++) {
        ERC20 asStrategy = ERC20(address(markets[j]));
        MidasFlywheelCore flywheel = MidasFlywheelCore(fws[i]);
        (uint224 index, ) = flywheel.strategyState(asStrategy);
        ERC20 rewToken = flywheel.rewardToken();
        if (index > 0) {
          uint256 allowance = rewToken.allowance(address(asStrategy), address(flywheel));
          if (allowance == 0) {
            assertGt(allowance, 0, "!approved");
            emit log_named_address("flywheel", address(flywheel));
            emit log_named_address("strategy", address(asStrategy));
            break;
          }
        }
      }
    }
  }
}
