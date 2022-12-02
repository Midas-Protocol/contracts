// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { IBeefyVault, BeefyERC4626 } from "../midas/strategies/BeefyERC4626.sol";
import { MidasERC4626 } from "../midas/strategies/MidasERC4626.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import "../compound/CErc20.sol";
import { ArrakisERC4626, IGuniPool } from "../midas/strategies/ArrakisERC4626.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract BeefyERC4626AccuralTest is BaseTest {
  using FixedPointMathLib for uint256;

  uint256 DEPOSIT_AMOUNT = 100e18;

  BeefyERC4626 plugin;
  ERC20Upgradeable underlyingToken;
  IBeefyVault beefyVault = IBeefyVault(0x122E09FdD2FF73C8CEa51D432c45A474BAa1518a); // jJPY-JPYC LP
  address beefyStrategy = 0xD9c0E8672b498bb28eFe95cEAa0D4E32e57Cc206;

  address accountOne = address(1);
  address accountTwo = address(2);

  function afterForkSetUp() internal override {
    underlyingToken = ERC20Upgradeable(address(beefyVault.want()));
    plugin = new BeefyERC4626();
    plugin.initialize(underlyingToken, beefyVault, 10);
  }

  // function testArrakisClaimRewards() public  {
  //   emit log_uint(CErc20(0xcb67Bd2aE0597eDb2426802CdF34bb4085d9483A).balanceOf(0x2924973E3366690eA7aE3FCdcb2b4e136Cf7f8Cc));
  //   ERC20Upgradeable mimo = ERC20Upgradeable(0xADAC33f543267c4D59a8c299cF804c303BC3e4aC);
  //   IGuniPool pool = IGuniPool(0xBA2D426DCb186d670eD54a759098947fad395C95);
  //   (uint256 staked, uint256 perShare) = pool.userInfo(0xd682451F627d54cfdA74a80972aDaeF133cdc15e);
  //   uint256 pendingMimo = pool.pendingMIMO(0xd682451F627d54cfdA74a80972aDaeF133cdc15e);
  //   ArrakisERC4626 plugin = ArrakisERC4626(0xd682451F627d54cfdA74a80972aDaeF133cdc15e);

  //   {
  //     address marketAddress = 0xcb67Bd2aE0597eDb2426802CdF34bb4085d9483A;

  //     uint256 balanceBefore = mimo.balanceOf(plugin.rewardDestination());

  //     plugin.claimRewards();

  //     uint256 balanceAfter = mimo.balanceOf(plugin.rewardDestination());

  //     FuseFlywheelDynamicRewardsPlugin flywheelRewards;
  //     FlywheelCore flywheel = FlywheelCore(0x5fF63E442AC4724EC342f4a3d26924233832EcBB);

  //     flywheelRewards = FuseFlywheelDynamicRewardsPlugin(address(flywheel.flywheelRewards()));

  //     emit log_address(address(flywheelRewards));

  //     // (uint224 index, uint32 timestamp) = flywheel.strategyState(ERC20(marketAddress));

  //     flywheel.accrue(ERC20(marketAddress), address(this));

  //     flywheel.accrue(ERC20(marketAddress), address(this));

  //     // (uint224 afterIndex, uint32 afterTimestamp) = flywheel.strategyState(ERC20(marketAddress));

  //     // ( , , uint192 mimoReward) = flywheelRewards.rewardsCycle(ERC20(address(marketAddress)));

  //     // emit log_uint(mimoReward);

  //     emit log_uint(pendingMimo);
  //     emit log_uint(balanceBefore);
  //     emit log_uint(balanceAfter);
  //     // emit log_uint(index);
  //     // emit log_uint(timestamp);
  //     // emit log_uint(afterIndex);
  //     // emit log_uint(afterTimestamp);
  //     emit log_uint(mimo.balanceOf(address(pool)));
  //   }
  // }

  /* --------------------- HELPER FUNCTIONS --------------------- */

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(plugin), amount);
    plugin.deposit(amount, _owner);
    vm.stopPrank();
  }

  function depositVault(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(beefyVault), amount);
    beefyVault.deposit(amount);
    vm.stopPrank();
  }

  function increaseAssetsInVault() public {
    deal(address(underlyingToken), address(beefyVault), 1000e18);
    beefyVault.earn();
  }

  /* --------------------- ERC4626 ACCURAL TESTS --------------------- */

  function testAccrualIsEqual() public fork(POLYGON_MAINNET) {
    deal(address(underlyingToken), accountOne, DEPOSIT_AMOUNT);
    deal(address(underlyingToken), accountTwo, DEPOSIT_AMOUNT);

    depositVault(accountOne, DEPOSIT_AMOUNT);
    deposit(accountTwo, DEPOSIT_AMOUNT);

    // increase vault balance
    increaseAssetsInVault();

    vm.warp(block.number + 150);

    vm.prank(accountOne);
    beefyVault.withdrawAll();

    uint256 erc4626Share = ERC20Upgradeable(plugin).balanceOf(accountTwo);

    vm.prank(accountTwo);
    plugin.redeem(erc4626Share, accountTwo, accountTwo);

    uint256 accountOneBalance = underlyingToken.balanceOf(accountOne);
    uint256 accountTwoBalance = underlyingToken.balanceOf(accountTwo);

    assertEq(accountOneBalance, accountTwoBalance, string(abi.encodePacked("!withdrawal balance")));
  }
}
