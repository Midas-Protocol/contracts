// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { WombatLpERC4626, IVoterProxy, IBaseRewardPool, IBooster } from "../../midas/strategies/WombatLpERC4626.sol";
import { MidasFlywheelCore } from "../../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { CErc20PluginRewardsDelegate } from "../../compound/CErc20PluginRewardsDelegate.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract WombatERC4626Test is AbstractERC4626Test {
  address operator = 0x9Ac0a3E8864Ea370Bf1A661444f6610dd041Ba1c;
  address marketAddress;

  uint256 poolId;
  IVoterProxy voterProxy = IVoterProxy(0xE3a7FB9C6790b02Dcfa03B6ED9cda38710413569);

  FlywheelCore[] flywheels;
  FuseFlywheelDynamicRewardsPlugin[] rewards;

  uint256[] internal rewardAmounts;
  uint192[] internal cycleRewards;

  ERC20 marketKey;
  ERC20Upgradeable[] rewardsToken;

  function _setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("wombat-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    (address _asset, uint256 _poolId, ERC20Upgradeable[] memory rewardTokens) = abi.decode(
      data,
      (address, uint256, ERC20Upgradeable[])
    );
    poolId = _poolId;
    rewardsToken = rewardTokens;

    testPreFix = _testPreFix;

    for (uint8 i = 0; i < rewardTokens.length; i++) {
      MidasFlywheelCore flywheel = new MidasFlywheelCore();
      flywheel.initialize(
        ERC20(address(rewardTokens[i])),
        IFlywheelRewards(address(0)),
        IFlywheelBooster(address(0)),
        address(this)
      );
      FuseFlywheelDynamicRewardsPlugin reward = new FuseFlywheelDynamicRewardsPlugin(
        FlywheelCore(address(flywheel)),
        1
      );
      flywheel.setFlywheelRewards(reward);

      flywheels.push(FlywheelCore(address(flywheel)));
      rewards.push(reward);
    }

    WombatLpERC4626 wombatLpERC4626 = new WombatLpERC4626();
    wombatLpERC4626.initialize(underlyingToken, voterProxy, poolId, rewardTokens, address(this));
    plugin = wombatLpERC4626;

    // Just set it explicitly to 0. Just wanted to make clear that this is not forgotten but expected to be 0
    initialStrategyBalance = getStrategyBalance();
    initialStrategySupply = 0;

    deployCErc20PluginRewardsDelegate(address(plugin), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));

    marketKey = ERC20(marketAddress);

    for (uint8 i = 0; i < rewardTokens.length; i++) {
      cToken.approve(address(rewardTokens[i]), address(rewards[i]));
      flywheels[i].addStrategyForRewards(marketKey);
    }

    WombatLpERC4626(address(plugin)).setRewardDestination(marketAddress);
  }

  function _baseRewardPool() internal view returns (IBaseRewardPool) {
    address booster = voterProxy.operator();
    (, , , address crvRewards, ) = IBooster(booster).poolInfo(poolId);
    return IBaseRewardPool(crvRewards);
  }

  function increaseAssetsInVault() public override {
    sendUnderlyingToken(100e18, address(_baseRewardPool()));
  }

  function decreaseAssetsInVault() public override {
    vm.prank(address(_baseRewardPool()));
    underlyingToken.transfer(address(1), 200e18);
  }

  function getDepositShares() public view override returns (uint256) {
    return _baseRewardPool().balanceOf(address(plugin));
  }

  function getStrategyBalance() public view override returns (uint256) {
    return _baseRewardPool().totalSupply();
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
      address(WombatLpERC4626(address(plugin)).voterProxy()),
      address(voterProxy),
      string(abi.encodePacked("!voterProxy ", testPreFix))
    );
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    vm.startPrank(address(this));
    underlyingToken.approve(marketAddress, depositAmount);
    CErc20PluginRewardsDelegate(marketAddress).mint(depositAmount);
    vm.stopPrank();

    for (uint8 i = 0; i < rewardsToken.length; i++) {
      deal(address(rewardsToken[i]), operator, 1000e18);
      vm.startPrank(operator);
      _baseRewardPool().queueNewRewards(address(rewardsToken[i]), 1000e18);
      vm.stopPrank();
    }

    for (uint8 i = 0; i < rewardsToken.length; i++) {
      (uint32 start, uint32 end, uint192 reward) = rewards[i].rewardsCycle(ERC20(address(marketAddress)));

      // Rewards can be transfered in the next cycle
      assertEq(end, 0, string(abi.encodePacked("!end-", vm.toString(i), " ", testPreFix)));

      // Reward amount is still 0
      assertEq(reward, 0, string(abi.encodePacked("!reward-", vm.toString(i), " ", testPreFix)));

      cycleRewards.push(reward);
    }

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    for (uint8 i = 0; i < rewardsToken.length; i++) {
      uint256 rewardBefore = rewardsToken[i].balanceOf(address(rewards[i]));
      // Call accrue as proxy for withdraw/deposit to claim rewards
      flywheels[i].accrue(ERC20(marketAddress), address(this));

      // Accrue rewards to send rewards to flywheelRewards
      flywheels[i].accrue(ERC20(marketAddress), address(this));

      assertGt(
        rewardsToken[i].balanceOf(address(rewards[i])),
        rewardBefore,
        string(abi.encodePacked("!rewardBal-", vm.toString(i), " ", testPreFix))
      );

      (uint256 start, uint256 end, uint192 reward) = rewards[i].rewardsCycle(ERC20(marketAddress));

      // Rewards can be transfered in the next cycle
      assertGt(end, 1000000000, string(abi.encodePacked("!2.end-", vm.toString(i), " ", testPreFix)));

      // Reward amount is expected value
      assertGt(reward, cycleRewards[i], string(abi.encodePacked("!2.reward-", vm.toString(i), " ", testPreFix)));
      cycleRewards[i] = reward;
    }

    vm.warp(block.timestamp + 150);
    vm.roll(20);

    for (uint8 i = 0; i < flywheels.length; i++) {
      // Finally accrue reward from last cycle
      flywheels[i].accrue(ERC20(marketAddress), address(this));

      // Claim Rewards for the user
      flywheels[i].claimRewards(address(this));

      emit log_uint(cycleRewards[i]);

      assertApproxEqAbs(
        rewardsToken[i].balanceOf(address(this)),
        cycleRewards[i],
        uint256(1000),
        string(abi.encodePacked("!rewardBal User-", vm.toString(i), " ", testPreFix))
      );
      assertEq(
        rewardsToken[i].balanceOf(address(flywheels[i])),
        0,
        string(abi.encodePacked("!rewardBal Flywheel-", vm.toString(i), " ", testPreFix))
      );
    }
  }
}
