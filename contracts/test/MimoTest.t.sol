// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";

import { MidasERC4626, ArrakisERC4626, IGuniPool } from "../midas/strategies/ArrakisERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../utils/FixedPointMathLib.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

// 34660263
contract MimoTest is BaseTest {
  using FixedPointMathLib for uint256;

  IGuniPool mimoStaking = IGuniPool(0x528330fF7c358FE1bAe348D23849CCed8edA5917);
  FlywheelCore flywheel = FlywheelCore(0x5fF63E442AC4724EC342f4a3d26924233832EcBB);
  FuseFlywheelDynamicRewardsPlugin flywheelRewards =
    FuseFlywheelDynamicRewardsPlugin(0x9c44eD0210a082CFA1378cd88BcE30dbA08daCb3);
  ArrakisERC4626 arrakisERC4626 = ArrakisERC4626(0xdE58CF12595e92ebB07D664eE59A642e360bea58);

  address mimoAddress = 0xADAC33f543267c4D59a8c299cF804c303BC3e4aC;
  ERC20 mimo = ERC20(mimoAddress);

  ERC20 underlyingToken = ERC20(address(0xC1DF4E2fd282e39346422e40C403139CD633Aacd));

  address marketAddress = 0xa5A14c3814d358230a56e8f011B8fc97A508E890;
  ERC20 marketKey = ERC20(marketAddress);
  CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);

  function setUp() public {
    vm.label(address(mimoStaking), "mimoStaking");
    vm.label(address(flywheel), "flywheel");
    vm.label(address(flywheelRewards), "flywheelRewards");
    vm.label(address(arrakisERC4626), "arrakisERC4626");
    vm.label(address(mimo), "mimo");
    vm.label(address(underlyingToken), "underlyingToken");
    vm.label(address(cToken), "cToken");
  }

  function testAccrue() public {
    flywheel.accrue(marketKey, address(0));
    assertEq(mimoStaking.pendingMIMO(address(arrakisERC4626)), 0);
    emit log_uint(mimo.balanceOf(address(arrakisERC4626)));
    emit log_uint(mimo.balanceOf(address(flywheelRewards)));
    emit log_uint(mimo.balanceOf(address(flywheel)));
    emit log_uint(mimo.balanceOf(address(cToken)));
    vm.warp(block.timestamp + 150);
    flywheel.accrue(marketKey, address(0));
    emit log("------");
    emit log_uint(mimo.balanceOf(address(arrakisERC4626)));
    emit log_uint(mimo.balanceOf(address(flywheelRewards)));
    emit log_uint(mimo.balanceOf(address(flywheel)));
    emit log_uint(mimo.balanceOf(address(cToken)));
  }
}
