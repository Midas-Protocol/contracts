// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { DotDotLpERC4626, ILpDepositor } from "../../midas/strategies/DotDotLpERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { CErc20PluginRewardsDelegate } from "../../compound/CErc20PluginRewardsDelegate.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract DotDotERC4626Test is AbstractERC4626Test {
  address whale = 0x0BC3a8239B0a63E945Ea1bd6722Ba747b9557e56;

  ILpDepositor lpDepositor = ILpDepositor(0x8189F0afdBf8fE6a9e13c69bA35528ac6abeB1af);
  ERC20 depositShare = ERC20(0xEFF5b0E496dC7C26fFaA014cEa0d2Baa83DB11c4);

  ERC20 dddToken = ERC20(0x84c97300a190676a19D1E13115629A11f8482Bd1);
  FlywheelCore dddFlywheel;
  FuseFlywheelDynamicRewardsPlugin dddRewards;

  ERC20 epxToken = ERC20(0xAf41054C1487b0e5E2B9250C0332eCBCe6CE9d71);
  FlywheelCore epxFlywheel;
  FuseFlywheelDynamicRewardsPlugin epxRewards;

  uint256 withdrawalFee = 10;
  uint256 ACCEPTABLE_DIFF = 1000;

  uint192 expectedReward = 1e18;
  address marketAddress;
  ERC20 marketKey;

  ERC20Upgradeable[] rewardsToken;

  function _setUp(string memory _testPreFix, bytes calldata) public override {
    setUpPool("dotdot-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    dddFlywheel = new FlywheelCore(
      dddToken,
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );
    dddRewards = new FuseFlywheelDynamicRewardsPlugin(dddFlywheel, 1);
    dddFlywheel.setFlywheelRewards(dddRewards);

    epxFlywheel = new FlywheelCore(
      epxToken,
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );
    epxRewards = new FuseFlywheelDynamicRewardsPlugin(epxFlywheel, 1);
    epxFlywheel.setFlywheelRewards(epxRewards);

    ERC20 dddFlywheelRewardToken = FlywheelCore(address(dddFlywheel)).rewardToken();
    rewardsToken.push(ERC20Upgradeable(address(dddFlywheelRewardToken)));
    ERC20 epxFlywheelRewardToken = FlywheelCore(address(epxFlywheel)).rewardToken();
    rewardsToken.push(ERC20Upgradeable(address(epxFlywheelRewardToken)));

    DotDotLpERC4626 dotDotLpERC4626 = new DotDotLpERC4626();
    dotDotLpERC4626.initialize(
      underlyingToken,
      FlywheelCore(address(dddFlywheel)),
      FlywheelCore(address(epxFlywheel)),
      ILpDepositor(address(lpDepositor)),
      address(this),
      rewardsToken
    );
    plugin = dotDotLpERC4626;

    // Just set it explicitly to 0. Just wanted to make clear that this is not forgotten but expected to be 0
    initialStrategyBalance = 0;
    initialStrategySupply = 0;

    deployCErc20PluginRewardsDelegate(address(plugin), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));

    cToken.approve(address(dddToken), address(dddRewards));
    cToken.approve(address(epxToken), address(epxRewards));

    marketKey = ERC20(marketAddress);

    dddFlywheel.addStrategyForRewards(marketKey);
    epxFlywheel.addStrategyForRewards(marketKey);
    DotDotLpERC4626(address(plugin)).setRewardDestination(marketAddress);
  }

  function increaseAssetsInVault() public override {
    sendUnderlyingToken(1000e18, address(lpDepositor));
  }

  function decreaseAssetsInVault() public override {
    vm.prank(0x5B74C99AA2356B4eAa7B85dC486843eDff8Dfdbe); //lpStaker
    underlyingToken.transfer(address(1), 200e18); // transfer doesnt work
  }

  function getDepositShares() public view override returns (uint256) {
    return depositShare.balanceOf(address(plugin));
  }

  function getStrategyBalance() public view override returns (uint256) {
    return lpDepositor.userBalances(address(plugin), underlyingToken);
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
      address(DotDotLpERC4626(address(plugin)).lpDepositor()),
      address(lpDepositor),
      string(abi.encodePacked("!lpDepositor ", testPreFix))
    );
  }

  function testAccumulatingRewardsOnDeposit() public {
    deposit(address(this), depositAmount / 2);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    deposit(address(this), depositAmount / 2);
    assertGt(dddToken.balanceOf(address(plugin)), 0.0006 ether, string(abi.encodePacked("!dddBal ", testPreFix)));
    assertGt(epxToken.balanceOf(address(plugin)), 0.01 ether, string(abi.encodePacked("!epxBal ", testPreFix)));
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    deposit(address(this), depositAmount);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    plugin.withdraw(1, address(this), address(this));

    assertGt(dddToken.balanceOf(address(plugin)), 0.001 ether, string(abi.encodePacked("!dddBal ", testPreFix)));
    assertGt(epxToken.balanceOf(address(plugin)), 0.025 ether, string(abi.encodePacked("!epxBal ", testPreFix)));
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    vm.startPrank(address(this));
    underlyingToken.approve(marketAddress, depositAmount);
    CErc20PluginRewardsDelegate(marketAddress).mint(depositAmount);
    vm.stopPrank();

    (uint32 dddStart, uint32 dddEnd, uint192 dddReward) = dddRewards.rewardsCycle(ERC20(address(marketAddress)));
    (uint32 epxStart, uint32 epxEnd, uint192 epxReward) = dddRewards.rewardsCycle(ERC20(address(marketAddress)));

    // Rewards can be transfered in the next cycle
    assertEq(dddEnd, 0, string(abi.encodePacked("!dddEnd ", testPreFix)));
    assertEq(epxEnd, 0, string(abi.encodePacked("!epxEnd ", testPreFix)));

    // Reward amount is still 0
    assertEq(dddReward, 0, string(abi.encodePacked("!dddReward ", testPreFix)));
    assertEq(epxReward, 0, string(abi.encodePacked("!epxReward ", testPreFix)));

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    // Call accrue as proxy for withdraw/deposit to claim rewards
    dddFlywheel.accrue(ERC20(marketAddress), address(this));
    epxFlywheel.accrue(ERC20(marketAddress), address(this));

    // Accrue rewards to send rewards to flywheelRewards
    dddFlywheel.accrue(ERC20(marketAddress), address(this));
    epxFlywheel.accrue(ERC20(marketAddress), address(this));
    assertGt(dddToken.balanceOf(address(dddRewards)), 0.001 ether, string(abi.encodePacked("!dddBal ", testPreFix)));
    assertGt(epxToken.balanceOf(address(epxRewards)), 0.025 ether, string(abi.encodePacked("!epxBal ", testPreFix)));

    (dddStart, dddEnd, dddReward) = dddRewards.rewardsCycle(ERC20(marketAddress));
    (epxStart, epxEnd, epxReward) = epxRewards.rewardsCycle(ERC20(marketAddress));

    // Rewards can be transfered in the next cycle
    assertGt(dddEnd, 1000000000, string(abi.encodePacked("!2.dddEnd ", testPreFix)));
    assertGt(epxEnd, 1000000000, string(abi.encodePacked("!2.epxEnd ", testPreFix)));

    // Reward amount is expected value
    assertGt(dddReward, 0.001 ether, string(abi.encodePacked("!2.dddReward ", testPreFix)));
    assertGt(epxReward, 0.025 ether, string(abi.encodePacked("!2.epxReward ", testPreFix)));

    vm.warp(block.timestamp + 150);
    vm.roll(20);

    // Finally accrue reward from last cycle
    dddFlywheel.accrue(ERC20(marketAddress), address(this));
    epxFlywheel.accrue(ERC20(marketAddress), address(this));

    // Claim Rewards for the user
    dddFlywheel.claimRewards(address(this));
    epxFlywheel.claimRewards(address(this));

    assertGt(dddToken.balanceOf(address(this)), 0.001 ether, string(abi.encodePacked("!dddBal User ", testPreFix)));
    assertEq(dddToken.balanceOf(address(dddFlywheel)), 0, string(abi.encodePacked("!dddBal Flywheel ", testPreFix)));
    assertGt(epxToken.balanceOf(address(this)), 0.025 ether, string(abi.encodePacked("!epxBal User ", testPreFix)));
    assertEq(epxToken.balanceOf(address(dddFlywheel)), 0, string(abi.encodePacked("!epxBal Flywheel ", testPreFix)));
  }
}
