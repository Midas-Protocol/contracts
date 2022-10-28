// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MidasERC4626, CurveGaugeERC4626, IChildGauge } from "../../midas/strategies/CurveGaugeERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

contract CurveERC4626Test is AbstractERC4626Test {
  using FixedPointMathLib for uint256;

  IChildGauge public gauge;

  FlywheelCore[] internal flywheels;
  FuseFlywheelDynamicRewardsPlugin[] internal rewardsPlugins;
  ERC20Upgradeable[] internal rewardsToken;

  uint256[] internal rewardAmounts;
  uint192[] internal cycleRewards;

  address internal marketAddress;
  ERC20 internal marketKey;

  constructor() WithPool() {}

  function setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("curve-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));
    (address _gauge, address _asset, address[] memory _rewardsToken) = abi.decode(data, (address, address, address[]));
    for (uint8 i; i < _rewardsToken.length; i++) {
      rewardsToken.push(ERC20Upgradeable(_rewardsToken[i]));
    }
    gauge = IChildGauge(_gauge);
    testPreFix = _testPreFix;
    CurveGaugeERC4626 curveERC4626 = new CurveGaugeERC4626();
    curveERC4626.initialize(ERC20Upgradeable(_asset), gauge, address(this), rewardsToken);

    plugin = curveERC4626;
    // Just set it explicitly to 0. Just wanted to make clear that this is not forgotten but expected to be 0
    initialStrategyBalance = 0;
    initialStrategySupply = 0;
    deployCErc20PluginRewardsDelegate(address(plugin), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));
    marketKey = ERC20(marketAddress);
    CurveGaugeERC4626(address(plugin)).setRewardDestination(marketAddress);
    for (uint8 i; i < _rewardsToken.length; i++) {
      FlywheelCore flywheel = new FlywheelCore(
        ERC20(_rewardsToken[i]),
        IFlywheelRewards(address(0)),
        IFlywheelBooster(address(0)),
        address(this),
        Authority(address(0))
      );
      FuseFlywheelDynamicRewardsPlugin rewardsPlugin = new FuseFlywheelDynamicRewardsPlugin(flywheel, 1);
      flywheel.setFlywheelRewards(rewardsPlugin);
      flywheels.push(flywheel);
      rewardsPlugins.push(rewardsPlugin);
      cToken.approve(_rewardsToken[i], address(rewardsPlugin));
      flywheel.addStrategyForRewards(marketKey);
    }
  }

  function increaseAssetsInVault() public override {
    // Cant Increase Assets in Vault
  }

  function decreaseAssetsInVault() public override {
    // Cant Decrease Assets in Vault
  }

  function getDepositShares() public view override returns (uint256) {
    return gauge.balanceOf(address(plugin));
  }

  function getStrategyBalance() public view override returns (uint256) {
    return gauge.balanceOf(address(plugin));
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return depositAmount;
  }

  function testInitializedValues(string memory assetName, string memory assetSymbol) public override {
    assertEq(
      plugin.name(),
      string(abi.encodePacked("Midas ", assetName, " Vault")),
      string(abi.encodePacked("!name ", testPreFix))
    );
    assertEq(
      plugin.symbol(),
      string(abi.encodePacked("mv", assetSymbol)),
      string(abi.encodePacked("!symbol ", testPreFix))
    );
    assertEq(address(plugin.asset()), address(underlyingToken), string(abi.encodePacked("!asset ", testPreFix)));
    assertEq(
      address(CurveGaugeERC4626(address(plugin)).gauge()),
      address(gauge),
      string(abi.encodePacked("!Gauge ", testPreFix))
    );
  }

  function testAccumulatingRewardsOnDeposit() public {
    deposit(address(this), depositAmount / 2);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    for (uint8 i; i < rewardsToken.length; i++) {
      rewardAmounts.push(rewardsToken[i].balanceOf(address(plugin)));
    }

    deposit(address(this), depositAmount / 2);
    for (uint8 i; i < rewardsToken.length; i++) {
      assertGt(
        rewardsToken[i].balanceOf(address(plugin)),
        rewardAmounts[i],
        string(abi.encodePacked("!rewardAmount-", vm.toString(i), " ", testPreFix))
      );
    }
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    deposit(address(this), depositAmount);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    for (uint8 i; i < rewardsToken.length; i++) {
      rewardAmounts.push(rewardsToken[i].balanceOf(address(plugin)));
    }

    plugin.withdraw(1, address(this), address(this));

    for (uint8 i; i < rewardsToken.length; i++) {
      assertGt(
        rewardsToken[i].balanceOf(address(plugin)),
        rewardAmounts[i],
        string(abi.encodePacked("!rewardAmount-", vm.toString(i), " ", testPreFix))
      );
    }
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    vm.startPrank(address(this));
    underlyingToken.approve(marketAddress, depositAmount);
    CErc20(marketAddress).mint(depositAmount);
    vm.stopPrank();

    for (uint8 i; i < flywheels.length; i++) {
      (uint32 cycleStart, uint32 cycleEnd, uint192 cycleReward) = rewardsPlugins[i].rewardsCycle(
        ERC20(address(marketAddress))
      );

      // Rewards can be transfered in the next cycle
      assertEq(cycleEnd, 0, string(abi.encodePacked("!cycleEnd-", vm.toString(i), " ", testPreFix)));

      // Reward amount is still 0
      assertEq(cycleReward, 0, string(abi.encodePacked("!cycleReward-", vm.toString(i), " ", testPreFix)));

      cycleRewards.push(cycleReward);
    }

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    for (uint8 i; i < flywheels.length; i++) {
      uint256 prevRewardAmount = rewardsToken[i].balanceOf(address(rewardsPlugins[i]));

      // Call accrue as proxy for withdraw/deposit to claim rewards
      flywheels[i].accrue(ERC20(marketAddress), address(this));

      // Accrue rewards to send rewards to flywheelRewards
      flywheels[i].accrue(ERC20(marketAddress), address(this));

      assertGt(
        rewardsToken[i].balanceOf(address(rewardsPlugins[i])),
        prevRewardAmount,
        string(abi.encodePacked("!rewardBal-", vm.toString(i), " ", testPreFix))
      );

      (uint32 cycleStart, uint32 cycleEnd, uint192 cycleReward) = rewardsPlugins[i].rewardsCycle(
        ERC20(address(marketAddress))
      );
      // Rewards can be transfered in the next cycle
      assertEq(cycleEnd, 1663093678, string(abi.encodePacked("!2.cycleEnd-", vm.toString(i), " ", testPreFix)));

      // Rewards can be transfered in the next cycle
      assertGt(
        cycleReward,
        cycleRewards[i],
        string(abi.encodePacked("!2.cycleReward-", vm.toString(i), " ", testPreFix))
      );
      cycleRewards[i] = cycleReward;
    }

    vm.warp(block.timestamp + 150);
    vm.roll(20);

    for (uint8 i; i < flywheels.length; i++) {
      // Finally accrue reward from last cycle
      flywheels[i].accrue(ERC20(marketAddress), address(this));

      // Claim Rewards for the user
      flywheels[i].claimRewards(address(this));

      assertEq(
        rewardsToken[i].balanceOf(address(this)),
        cycleRewards[i],
        string(abi.encodePacked("!RewardBal User-", vm.toString(i), " ", testPreFix))
      );
      assertEq(
        rewardsToken[i].balanceOf(address(flywheels[i])),
        0,
        string(abi.encodePacked("!RewardBal Flywheel-", vm.toString(i), " ", testPreFix))
      );
    }
  }
}
