// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import "../midas/strategies/ThenaLpERC4626.sol";

import { ERC20Upgradeable as ERC20 } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ERC20 as SolERC20 } from "solmate/tokens/ERC20.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

contract ThenaLpERC4626Test is BaseTest {
  ThenaLpERC4626 public plugin;
  MidasFlywheel public flywheel;
  ERC20 public thenaToken = ERC20(0xF4C8E32EaDEC4BFe97E0F595AdD0f4450a863a11);
  ERC20 public lpHayBusdToken = ERC20(0x93B32a8dfE10e9196403dd111974E325219aec24);
  address public lpTokenWhale = 0xE43317c1f037CBbaF33F33C386f2cAF2B6b25C9C; // gauge v2
  address public marketAddress = address(123);

  function afterForkSetUp() internal override {
    address dpa = address(929292);
    vm.prank(lpTokenWhale);
    lpHayBusdToken.transfer(address(this), 1e22);

    {
      ThenaLpERC4626 impl = new ThenaLpERC4626();
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), dpa, "");
      plugin = ThenaLpERC4626(address(proxy));
    }

    {
      MidasFlywheel impl = new MidasFlywheel();
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), dpa, "");
      flywheel = MidasFlywheel(address(proxy));
    }
    flywheel.initialize(
      SolERC20(address(thenaToken)),
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this)
    );

    FuseFlywheelDynamicRewards rewardsContract = new FuseFlywheelDynamicRewards(
      FlywheelCore(address(flywheel)),
      1 days
    );
    flywheel.setFlywheelRewards(rewardsContract);

    plugin.initialize(lpHayBusdToken, marketAddress, flywheel);
  }

  function testThenaPluginDeposit() public fork(BSC_MAINNET) {
    lpHayBusdToken.approve(address(plugin), 1e36);
    uint256 depositAmount = 1e6;
    uint256 sharesMinted = plugin.deposit(depositAmount, address(this));

    assertEq(sharesMinted, depositAmount, "!init shares");
  }

  function testThenaPluginAccrueRewards() public fork(BSC_MAINNET) {
    lpHayBusdToken.approve(address(plugin), 1e36);
    uint256 sharesMinted = plugin.deposit(1e16, address(this));
    emit log_named_uint("shares minted", sharesMinted);

    ERC20 rewardToken = plugin.rewardTokens(0);
    uint256 rewardsBalanceBefore = rewardToken.balanceOf(marketAddress);

    vm.warp(block.timestamp + 1e7);
    vm.roll(block.number + 9999);

    plugin.claimRewards();

    uint256 rewardsBalanceAfter = rewardToken.balanceOf(marketAddress);
    uint256 rewardsDiff = rewardsBalanceAfter - rewardsBalanceBefore;
    emit log_named_uint("rewards diff", rewardsDiff);
    assertGt(rewardsDiff, 0, "!no rewards claimed");
  }
}
