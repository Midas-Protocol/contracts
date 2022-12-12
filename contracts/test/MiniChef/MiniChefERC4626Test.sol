// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { MiniChefERC4626, IMiniChefV2, IRewarder } from "../../midas/strategies/MiniChefERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { MidasFlywheelCore } from "../../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { CErc20PluginRewardsDelegate } from "../../compound/CErc20PluginRewardsDelegate.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract MiniChefERC4626Test is AbstractERC4626Test {
  FlywheelCore[] flywheels;
  FuseFlywheelDynamicRewardsPlugin[] rewards;
  IMiniChefV2 miniChef = IMiniChefV2(0x067eC87844fBD73eDa4a1059F30039584586e09d);
  address marketAddress;
  ERC20 marketKey;
  ERC20Upgradeable[] rewardTokens;
  uint256 poolId;

  uint256[] internal rewardAmounts;
  uint192[] internal cycleRewards;

  function _setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("MiniChef-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    (address _asset, address[] memory _rewardTokens, uint256 _poolId) = abi.decode(data, (address, address[], uint256));

    poolId = _poolId;
    for (uint8 i = 0; i < _rewardTokens.length; i++) {
      MidasFlywheelCore flywheel = new MidasFlywheelCore();
      flywheel.initialize(
        ERC20(_rewardTokens[i]),
        IFlywheelRewards(address(0)),
        IFlywheelBooster(address(0)),
        address(this)
      );

      FuseFlywheelDynamicRewardsPlugin reward = new FuseFlywheelDynamicRewardsPlugin(
        FlywheelCore(address(flywheel)),
        1
      );
      flywheel.setFlywheelRewards(reward);

      rewardTokens.push(ERC20Upgradeable(_rewardTokens[i]));
      flywheels.push(FlywheelCore(address(flywheel)));
      rewards.push(reward);
    }

    MiniChefERC4626 miniChefERC4626 = new MiniChefERC4626();
    miniChefERC4626.initialize(underlyingToken, poolId, miniChef, address(this), rewardTokens);
    plugin = miniChefERC4626;

    initialStrategyBalance = getStrategyBalance();

    deployCErc20PluginRewardsDelegate(address(plugin), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));

    marketKey = ERC20(marketAddress);

    for (uint8 i = 0; i < rewardTokens.length; i++) {
      cToken.approve(_rewardTokens[i], address(rewards[i]));
      flywheels[i].addStrategyForRewards(marketKey);
    }

    MiniChefERC4626(address(plugin)).setRewardDestination(marketAddress);
  }

  function increaseAssetsInVault() public override {
    deal(address(underlyingToken), address(1), 1e18);
    vm.prank(address(1));
    underlyingToken.transfer(address(miniChef), 1e18);
  }

  function decreaseAssetsInVault() public override {
    vm.prank(address(miniChef));
    underlyingToken.transfer(address(1), 2e18);
  }

  function getDepositShares() public view override returns (uint256) {
    return miniChef.userInfo(poolId, address(plugin)).amount;
  }

  function getStrategyBalance() public view override returns (uint256) {
    return underlyingToken.balanceOf(address(miniChef));
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
      address(MiniChefERC4626(address(plugin)).miniChef()),
      address(miniChef),
      string(abi.encodePacked("!miniChef ", testPreFix))
    );
    assertEq(MiniChefERC4626(address(plugin)).poolId(), poolId, string(abi.encodePacked("!poolId", testPreFix)));
  }

  function testAccumulatingRewardsOnDeposit() public {
    deposit(address(this), depositAmount / 2);

    IRewarder rewarder = miniChef.rewarder(poolId);
    (, uint256[] memory amounts) = rewarder.pendingTokens(poolId, address(plugin), 0);

    deposit(address(this), depositAmount / 2);

    assertEq(rewardTokens[0].balanceOf(address(plugin)), amounts[0], string(abi.encodePacked("!diffBal ", testPreFix)));
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    deposit(address(this), depositAmount);

    IRewarder rewarder = miniChef.rewarder(poolId);
    (, uint256[] memory amounts) = rewarder.pendingTokens(poolId, address(plugin), 0);

    plugin.withdraw(1, address(this), address(this));

    assertEq(rewardTokens[0].balanceOf(address(plugin)), amounts[0], string(abi.encodePacked("!diffBal ", testPreFix)));
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    vm.startPrank(address(this));
    underlyingToken.approve(marketAddress, depositAmount);
    CErc20PluginRewardsDelegate(marketAddress).mint(depositAmount);
    vm.stopPrank();

    for (uint8 i = 0; i < rewardTokens.length; i++) {
      (uint32 start, uint32 end, uint192 reward) = rewards[i].rewardsCycle(ERC20(address(marketAddress)));

      // Rewards can be transfered in the next cycle
      assertEq(end, 0, string(abi.encodePacked("!end-", vm.toString(i), " ", testPreFix)));

      // Reward amount is still 0
      assertEq(reward, 0, string(abi.encodePacked("!reward-", vm.toString(i), " ", testPreFix)));

      cycleRewards.push(reward);
    }

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    for (uint8 i = 0; i < rewardTokens.length; i++) {
      uint256 rewardBefore = rewardTokens[i].balanceOf(address(rewards[i]));
      // Call accrue as proxy for withdraw/deposit to claim rewards
      flywheels[i].accrue(ERC20(marketAddress), address(this));

      // Accrue rewards to send rewards to flywheelRewards
      flywheels[i].accrue(ERC20(marketAddress), address(this));

      assertGt(
        rewardTokens[i].balanceOf(address(rewards[i])),
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
        rewardTokens[i].balanceOf(address(this)),
        cycleRewards[i],
        uint256(1000),
        string(abi.encodePacked("!rewardBal User-", vm.toString(i), " ", testPreFix))
      );
      assertEq(
        rewardTokens[i].balanceOf(address(flywheels[i])),
        0,
        string(abi.encodePacked("!rewardBal Flywheel-", vm.toString(i), " ", testPreFix))
      );
    }
  }
}
