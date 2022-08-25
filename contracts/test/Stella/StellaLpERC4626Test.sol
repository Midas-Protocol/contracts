// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MidasERC4626, StellaLpERC4626, IStellaDistributorV2 } from "../../compound/strategies/StellaLpERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

// Tested on block 19052824
contract StellaERC4626Test is AbstractERC4626Test {
  using FixedPointMathLib for uint256;

  IStellaDistributorV2 distributor = IStellaDistributorV2(0xF3a5454496E26ac57da879bf3285Fa85DEBF0388); // what you deposit the LP into
  ERC20 depositShare = ERC20(0xEFF5b0E496dC7C26fFaA014cEa0d2Baa83DB11c4);

  FlywheelCore[] flywheels;
  FuseFlywheelDynamicRewardsPlugin[] rewards;

  ERC20 dddToken = ERC20(0x84c97300a190676a19D1E13115629A11f8482Bd1);
  FlywheelCore dddFlywheel;
  FuseFlywheelDynamicRewardsPlugin dddRewards;

  ERC20 epxToken = ERC20(0xAf41054C1487b0e5E2B9250C0332eCBCe6CE9d71);
  FlywheelCore epxFlywheel;
  FuseFlywheelDynamicRewardsPlugin epxRewards;

  uint256 withdrawalFee = 10;
  uint256 ACCEPTABLE_DIFF = 1000;
  uint256 poolId;

  uint192 expectedReward = 1e18;
  address marketAddress;
  ERC20 marketKey;

  ERC20[] rewardsToken;

  constructor() WithPool() {}

  function setUp(string memory _testPreFix, bytes calldata testConfig) public override {
    setUpPool("stella-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));
    (address asset, uint256 _poolId, address[] memory _rewardTokens) = abi.decode(testConfig, (address, uint256, address[]));

    testPreFix = _testPreFix;
    poolId = _poolId;

    for (uint256 i = 0; i < _rewardTokens.length; i += 1) {
      FlywheelCore _flywheel = new FlywheelCore(
        ERC20(_rewardTokens[i]),
        IFlywheelRewards(address(0)),
        IFlywheelBooster(address(0)),
        address(this),
        Authority(address(0))
      );
      FuseFlywheelDynamicRewardsPlugin _reward = new FuseFlywheelDynamicRewardsPlugin(_flywheel, 1);
      flywheels.push(_flywheel);
      rewards.push(_reward);
      _flywheel.setFlywheelRewards(_reward);  

      rewardsToken.push(ERC20(_rewardTokens[i]));
    }

    plugin = MidasERC4626(
      address(
        new StellaLpERC4626(
          underlyingToken,
          flywheels,
          IStellaDistributorV2(address(distributor)),
          poolId,
          address(this),
          rewardsToken
        )
      )
    );

    // Just set it explicitly to 0. Just wanted to make clear that this is not forgotten but expected to be 0
    initialStrategyBalance = 0;
    initialStrategySupply = 0;

    deployCErc20PluginRewardsDelegate(ERC4626(address(plugin)), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));

    marketKey = ERC20(marketAddress);

    for (uint256 i = 0; i < _rewardTokens.length; i += 1) {
      cToken.approve(address(_rewardTokens[i]), address(rewards[i]));
      flywheels[i].addStrategyForRewards(marketKey);
    }

    StellaLpERC4626(address(plugin)).setRewardDestination(marketAddress);
  }

  function increaseAssetsInVault() public override {
    sendUnderlyingToken(1000e18, address(distributor));
  }

  function decreaseAssetsInVault() public override {
    vm.prank(0x5B74C99AA2356B4eAa7B85dC486843eDff8Dfdbe); //lpStaker
    underlyingToken.transfer(address(1), 200e18); // transfer doesnt work
  }

  // figure out how to get balance of plugin in LP staker contract
  // make sure it is not balance of underlying, rather balance of shares
  function getDepositShares() public view override returns (uint256) {
    (uint256 amount, , ,) = distributor.userInfo(poolId, address(plugin));
    return amount;
  }

  function getStrategyBalance() public view override returns (uint256) {
    return distributor.poolTotalLp(poolId);
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return depositAmount;
  }

  function testInitializedValues(string memory assetName, string memory assetSymbol)
    public
    override
    shouldRun(forChains(BSC_MAINNET))
  {
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
      address(StellaLpERC4626(address(plugin)).distributor()),
      address(distributor),
      string(abi.encodePacked("!distributor ", testPreFix))
    );
  }

  // function testAccumulatingRewardsOnDeposit() public {
  //   deposit(address(this), depositAmount / 2);

  //   vm.warp(block.timestamp + 150);
  //   vm.roll(10);

  //   deposit(address(this), depositAmount / 2);
  //   assertGt(dddToken.balanceOf(address(plugin)), 0.0006 ether, string(abi.encodePacked("!dddBal ", testPreFix)));
  //   assertGt(epxToken.balanceOf(address(plugin)), 0.01 ether, string(abi.encodePacked("!epxBal ", testPreFix)));
  // }

  // function testAccumulatingRewardsOnWithdrawal() public {
  //   deposit(address(this), depositAmount);

  //   vm.warp(block.timestamp + 150);
  //   vm.roll(10);

  //   plugin.withdraw(1, address(this), address(this));

  //   assertGt(dddToken.balanceOf(address(plugin)), 0.001 ether, string(abi.encodePacked("!dddBal ", testPreFix)));
  //   assertGt(epxToken.balanceOf(address(plugin)), 0.025 ether, string(abi.encodePacked("!epxBal ", testPreFix)));
  // }

  // function testClaimRewards() public {
  //   // Deposit funds, Rewards are 0
  //   vm.startPrank(address(this));
  //   underlyingToken.approve(marketAddress, depositAmount);
  //   CErc20(marketAddress).mint(depositAmount);
  //   vm.stopPrank();

  //   (uint32 dddStart, uint32 dddEnd, uint192 dddReward) = dddRewards.rewardsCycle(ERC20(address(marketAddress)));
  //   (uint32 epxStart, uint32 epxEnd, uint192 epxReward) = dddRewards.rewardsCycle(ERC20(address(marketAddress)));

  //   // Rewards can be transfered in the next cycle
  //   assertEq(dddEnd, 0, string(abi.encodePacked("!dddEnd ", testPreFix)));
  //   assertEq(epxEnd, 0, string(abi.encodePacked("!epxEnd ", testPreFix)));

  //   // Reward amount is still 0
  //   assertEq(dddReward, 0, string(abi.encodePacked("!dddReward ", testPreFix)));
  //   assertEq(epxReward, 0, string(abi.encodePacked("!epxReward ", testPreFix)));

  //   vm.warp(block.timestamp + 150);
  //   vm.roll(10);

  //   // Call accrue as proxy for withdraw/deposit to claim rewards
  //   dddFlywheel.accrue(ERC20(marketAddress), address(this));
  //   epxFlywheel.accrue(ERC20(marketAddress), address(this));

  //   // Accrue rewards to send rewards to flywheelRewards
  //   dddFlywheel.accrue(ERC20(marketAddress), address(this));
  //   epxFlywheel.accrue(ERC20(marketAddress), address(this));
  //   assertGt(dddToken.balanceOf(address(dddRewards)), 0.001 ether, string(abi.encodePacked("!dddBal ", testPreFix)));
  //   assertGt(epxToken.balanceOf(address(epxRewards)), 0.025 ether, string(abi.encodePacked("!epxBal ", testPreFix)));

  //   (dddStart, dddEnd, dddReward) = dddRewards.rewardsCycle(ERC20(marketAddress));
  //   (epxStart, epxEnd, epxReward) = epxRewards.rewardsCycle(ERC20(marketAddress));

  //   // Rewards can be transfered in the next cycle
  //   assertGt(dddEnd, 1000000000, string(abi.encodePacked("!2.dddEnd ", testPreFix)));
  //   assertGt(epxEnd, 1000000000, string(abi.encodePacked("!2.epxEnd ", testPreFix)));

  //   // Reward amount is expected value
  //   assertGt(dddReward, 0.001 ether, string(abi.encodePacked("!2.dddReward ", testPreFix)));
  //   assertGt(epxReward, 0.025 ether, string(abi.encodePacked("!2.epxReward ", testPreFix)));

  //   vm.warp(block.timestamp + 150);
  //   vm.roll(20);

  //   // Finally accrue reward from last cycle
  //   dddFlywheel.accrue(ERC20(marketAddress), address(this));
  //   epxFlywheel.accrue(ERC20(marketAddress), address(this));

  //   // Claim Rewards for the user
  //   dddFlywheel.claimRewards(address(this));
  //   epxFlywheel.claimRewards(address(this));

  //   assertGt(dddToken.balanceOf(address(this)), 0.001 ether, string(abi.encodePacked("!dddBal User ", testPreFix)));
  //   assertEq(dddToken.balanceOf(address(dddFlywheel)), 0, string(abi.encodePacked("!dddBal Flywheel ", testPreFix)));
  //   assertGt(epxToken.balanceOf(address(this)), 0.025 ether, string(abi.encodePacked("!epxBal User ", testPreFix)));
  //   assertEq(epxToken.balanceOf(address(dddFlywheel)), 0, string(abi.encodePacked("!epxBal Flywheel ", testPreFix)));
  // }
}
