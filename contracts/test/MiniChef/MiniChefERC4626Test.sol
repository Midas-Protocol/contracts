// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { WithPool } from "../helpers/WithPool.sol";
import { BaseTest } from "../config/BaseTest.t.sol";

import { MidasERC4626, MiniChefERC4626, IMiniChefV2 } from "../../midas/strategies/MiniChefERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { CErc20PluginRewardsDelegate } from "../../compound/CErc20PluginRewardsDelegate.sol";
import { CErc20 } from "../../compound/CErc20.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

contract MiniChefERC4626Test is AbstractERC4626Test {
  using FixedPointMathLib for uint256;

  FlywheelCore flywheel;
  FuseFlywheelDynamicRewardsPlugin flywheelRewards;
  address jrtMimoSep22Token = 0xAFC780bb79E308990c7387AB8338160bA8071B67;
  IMiniChefV2 miniChef = IMiniChefV2(0x067eC87844fBD73eDa4a1059F30039584586e09d);
  address marketAddress;
  ERC20 marketKey;
  ERC20Upgradeable[] rewardTokens;
  uint256 poolId;

  constructor() WithPool() {}

  function setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("MiniChef-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    (address _asset, address _rewardToken, uint256 _poolId) = abi.decode(data, (address, address, uint256));

    flywheel = new FlywheelCore(
      ERC20(_rewardToken),
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    rewardTokens.push(ERC20Upgradeable(_rewardToken));
    vm.mockCall(
      address(rewardTokens[0]),
      abi.encodeWithSelector(rewardTokens[0].balanceOf.selector, address(0)),
      abi.encode(0)
    );

    flywheelRewards = new FuseFlywheelDynamicRewardsPlugin(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    poolId = _poolId;


    MiniChefERC4626 miniChefERC4626 = new MiniChefERC4626();
    miniChefERC4626.initialize(underlyingToken, flywheel, poolId, miniChef, address(this), rewardTokens);
    plugin = miniChefERC4626;

    initialStrategyBalance = getStrategyBalance();

    deployCErc20PluginRewardsDelegate(address(plugin), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));

    cToken.approve(_rewardToken, address(flywheelRewards));

    marketKey = ERC20(marketAddress);

    flywheel.addStrategyForRewards(marketKey);
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

  // function testAccumulatingRewardsOnDeposit() public {
  //   deposit(address(this), depositAmount / 2);
  //   deal(address(jrtMimoSep22Token), address(this), 100e18);
  //   ERC20(jrtMimoSep22Token).transfer(address(miniChef), 100e18);

  //   uint256 expectedReward = miniChef.pendingRwd(poolId, address(plugin));

  //   deposit(address(this), depositAmount / 2);

  //   assertEq(
  //     ERC20(jrtMimoSep22Token).balanceOf(address(plugin)),
  //     expectedReward,
  //     string(abi.encodePacked("!mimoBal ", testPreFix))
  //   );
  // }

  // function testAccumulatingRewardsOnWithdrawal() public {
  //   deposit(address(this), depositAmount);
  //   deal(address(jrtMimoSep22Token), address(this), 100e18);
  //   ERC20(jrtMimoSep22Token).transfer(address(miniChef), 100e18);

  //   uint256 expectedReward = miniChef.pendingRwd(poolId, address(plugin));

  //   plugin.withdraw(1, address(this), address(this));

  //   assertEq(
  //     ERC20(jrtMimoSep22Token).balanceOf(address(plugin)),
  //     expectedReward,
  //     string(abi.encodePacked("!mimoBal ", testPreFix))
  //   );
  // }

  // function testClaimRewards() public {
  //   vm.startPrank(address(this));
  //   underlyingToken.approve(marketAddress, depositAmount);
  //   CErc20(marketAddress).mint(depositAmount);
  //   vm.stopPrank();

  //   deal(address(jrtMimoSep22Token), address(this), 100e18);
  //   ERC20(jrtMimoSep22Token).transfer(address(miniChef), 100e18);
  //   uint256 expectedReward = miniChef.pendingRwd(poolId, address(plugin));

  //   (uint32 mimoStart, uint32 mimoEnd, uint192 mimoReward) = flywheelRewards.rewardsCycle(
  //     ERC20(address(marketAddress))
  //   );

  //   // Rewards can be transfered in the next cycle
  //   assertEq(mimoEnd, 0, string(abi.encodePacked("!mimoEnd ", testPreFix)));

  //   // Reward amount is still 0
  //   assertEq(mimoReward, 0, string(abi.encodePacked("!mimoReward ", testPreFix)));

  //   vm.warp(block.timestamp + 150);
  //   vm.roll(20);

  //   // Call accrue as proxy for withdraw/deposit to claim rewards
  //   flywheel.accrue(ERC20(marketAddress), address(this));

  //   // Accrue rewards to send rewards to flywheelRewards
  //   flywheel.accrue(ERC20(marketAddress), address(this));

  //   (mimoStart, mimoEnd, mimoReward) = flywheelRewards.rewardsCycle(ERC20(address(marketAddress)));

  //   // Rewards can be transfered in the next cycle
  //   assertGt(mimoEnd, 1000000000, string(abi.encodePacked("!2.mimoEnd ", testPreFix)));
  //   assertApproxEqAbs(
  //     mimoReward,
  //     expectedReward,
  //     uint256(1000),
  //     string(abi.encodePacked("!2.mimoReward ", testPreFix))
  //   );

  //   vm.warp(block.timestamp + 150);
  //   vm.roll(20);

  //   flywheel.accrue(ERC20(marketAddress), address(this));

  //   // Claim Rewards for the user
  //   flywheel.claimRewards(address(this));

  //   assertApproxEqAbs(
  //     ERC20(jrtMimoSep22Token).balanceOf(address(this)),
  //     expectedReward,
  //     uint256(1000),
  //     string(abi.encodePacked("!mimoBal User ", testPreFix))
  //   );
  //   assertEq(
  //     ERC20(jrtMimoSep22Token).balanceOf(address(flywheel)),
  //     0,
  //     string(abi.encodePacked("!mimoBal Flywheel ", testPreFix))
  //   );
  // }
}
