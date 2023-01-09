// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { MidasReplacingFlywheel } from "../midas/strategies/flywheel/MidasReplacingFlywheel.sol";
import { ReplacingFlywheelDynamicRewards } from "../midas/strategies/flywheel/rewards/ReplacingFlywheelDynamicRewards.sol";
import { MidasFlywheelLensRouter } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";
import { CErc20PluginRewardsDelegate } from "../compound/CErc20PluginRewardsDelegate.sol";
import { FusePoolLensSecondary } from "../FusePoolLensSecondary.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { IERC20MetadataUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

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

  function testMoonbeamRewards() public fork(MOONBEAM_MAINNET) {
    address deployer = 0x82eDcFe00bd0ce1f3aB968aF09d04266Bc092e0E;
    address user = 0x2924973E3366690eA7aE3FCdcb2b4e136Cf7f8Cc;
    user = deployer;
    uint256[] memory pids;
    IComptroller[] memory pools;
    address[][] memory distributrs;

    FusePoolLensSecondary poolLensSecondary = new FusePoolLensSecondary();
    poolLensSecondary.initialize(fpd);
    (pids, pools, distributrs) = poolLensSecondary.getFlywheelsToClaim(user);

    for (uint256 i = 0; i < pools.length; i++) {
      emit log_named_address("pools", address(pools[i]));
      emit log_named_uint("pid", pids[i]);
    }

    for (uint256 i = 0; i < distributrs.length; i++) {
      emit log_named_array("distributrs", distributrs[i]);
    }
  }

  function testAccruedFlywheels() public fork(MOONBEAM_MAINNET) {
    address user = 0x2924973E3366690eA7aE3FCdcb2b4e136Cf7f8Cc;
    address deployer = 0x82eDcFe00bd0ce1f3aB968aF09d04266Bc092e0E;
    user = deployer;
    (, FusePoolDirectory.FusePool[] memory pools) = fpd.getActivePools();

    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, 0xa9736bA05de1213145F688e4619E5A7e0dcf4C72),
      abi.encode(34315417857347)
    );
    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, 0xc6e37086D09ec2048F151D11CdB9F9BbbdB7d685),
      abi.encode(15786961530391797)
    );
    vm.mockCall(
      0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080,
      abi.encodeWithSelector(IERC20MetadataUpgradeable.decimals.selector),
      abi.encode(10)
    );

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);

      address[] memory fws = pool.getRewardsDistributors();
      ICToken[] memory markets = pool.getAllMarkets();

      for (uint8 j = 0; j < fws.length; j++) {
        MidasFlywheel fw = MidasFlywheel(fws[j]);
        emit log_named_address("fw", fws[j]);
        emit log_named_uint("rewards accrued", fw.rewardsAccrued(user));
        for (uint8 k = 0; k < markets.length; k++) {
          ERC20 strategy = ERC20(address(markets[k]));
          fw.accrue(strategy, user);
        }
        emit log_named_uint("comp accrued", fw.compAccrued(user));
        emit log("");
      }
    }
  }
}
