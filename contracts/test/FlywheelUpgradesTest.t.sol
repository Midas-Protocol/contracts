// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { MidasFlywheelLensRouter } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";

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

  function testFlywheelUpgradeBsc() public debuggingOnly fork(BSC_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradePolygon() public debuggingOnly fork(POLYGON_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradeMoonbeam() public debuggingOnly fork(MOONBEAM_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradeEvmos() public debuggingOnly fork(EVMOS_MAINNET) {
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
          vm.prank(admin);
          proxy.upgradeTo(address(newImpl));
          emit log_named_address("upgradable flywheel", address(flywheel));

          bool anyStrategyHasPositiveIndex = false;

          for (uint8 k = 0; k < markets.length; k++) {
            ERC20 strategy = ERC20(address(markets[k]));
            (uint224 index, uint32 ts) = flywheel.strategyState(strategy);
            if (index > 0) {
              anyStrategyHasPositiveIndex = true;
              break;
            }
          }

          if (!anyStrategyHasPositiveIndex)
            emit log_named_address("all zero index strategies flywheel", address(flywheel));
          //assertTrue(anyStrategyHasPositiveIndex, "!flywheel has no strategies added or is broken");
        } else {
          //assertTrue(false, "flywheel proxy admin 0");
          emit log_named_address("not upgradable flywheel", address(flywheel));
        }
      }
    }
  }

  function testUserExcessEPXRewards() public debuggingOnly fork(BSC_MAINNET) {
    //     ├─ [4382] 0x44FE7D9bb9b2880BE71c2484F0070D8C35CacB41::getUnclaimedRewardsForMarket(0xC3A9b350eBBCDD14B96934B6831f1978431D9B8c, 0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba, [0xC6431455AeE17a08D6409BdFB18c4bc73a4069E4], [true])
    address user = 0xC3A9b350eBBCDD14B96934B6831f1978431D9B8c;
    address flywheelAddress = 0xC6431455AeE17a08D6409BdFB18c4bc73a4069E4;
    ERC20 strategy = ERC20(0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba); // 2brl market

    MidasFlywheelCore epxFlywheel = MidasFlywheelCore(flywheelAddress);
    FlywheelDynamicRewards rewardsContract = FlywheelDynamicRewards(address(epxFlywheel.flywheelRewards()));

    //    (uint224 twoBrlIndex, ) = epxFlywheel.strategyState(strategy);
    //    emit log_named_uint("twoBrlIndex", twoBrlIndex); // 4992296588989034096
    //
    //    uint224 userIndex = epxFlywheel.userIndex(strategy, user);
    //    emit log_named_uint("userIndex", userIndex); //     3206627362250415593

    MidasFlywheelLensRouter lensRouter = new MidasFlywheelLensRouter();

    MidasFlywheelCore[] memory flywheels = new MidasFlywheelCore[](1);
    flywheels[0] = epxFlywheel;
    uint256[] memory rewards = lensRouter.getUnclaimedRewardsForMarket(user, strategy, flywheels, asArray(true));

    emit log_named_uint("rewards for flywheel", rewards[0]);
  }

  function testBrokenStorageLayout() public {
    vm.selectFork(vm.createFork("https://moonbeam.public.blastapi.io"));
    ERC20 strategy = ERC20(0x32Be4b977BaB44e9146Bb414c18911e652C56568); // wglmr-xcdot market
    address brokenFlywheelAddress = 0x34022232C0233Ee05FDe3383FcEC52248Dd84b91;
    MidasFlywheelCore brokenFlywheel = MidasFlywheelCore(brokenFlywheelAddress);
    address user = 0x22f5413C075Ccd56D575A54763831C4c27A37Bdb;
    address stella = 0x0E358838ce72d5e61E0018a2ffaC4bEC5F4c88d2;

    uint256 blockFlywheelDeployed = 1864419;
    uint256 blocksInterval = (block.number - blockFlywheelDeployed) / 10;

    for (uint8 i = 0; i <= 10; i++) {
      vm.rollFork(blockFlywheelDeployed + i * blocksInterval);

      emit log("");
      emit log_uint(i);
      emit log_named_uint("at block", block.number);
      TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(brokenFlywheel)));
      bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
      address admin = address(uint160(uint256(bytesAtSlot)));
      vm.prank(admin);
      address impl = proxy.implementation();
      emit log_named_address("impl", impl);
      (uint224 strategyIndex, ) = brokenFlywheel.strategyState(strategy);
      emit log_named_uint("strategy index1", strategyIndex);

      uint224 userIndex = brokenFlywheel.userIndex(strategy, user);
      emit log_named_uint("userIndex1", userIndex);

      deal(0x0E358838ce72d5e61E0018a2ffaC4bEC5F4c88d2, address(strategy), 100 ether);

      brokenFlywheel.accrue(strategy, address(0));

      (strategyIndex, ) = brokenFlywheel.strategyState(strategy);
      emit log_named_uint("strategy index2", strategyIndex);

      userIndex = brokenFlywheel.userIndex(strategy, user);
      emit log_named_uint("userIndex", userIndex);
    }
  }
}
