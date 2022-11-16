// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MidasERC4626, HelioERC4626, IJAR } from "../../midas/strategies/HelioERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

contract HelioERC4626Test is AbstractERC4626Test {
  using FixedPointMathLib for uint256;

  IJAR jar;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewardsPlugin flywheelRewards;
  address heyToken = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
  address ward = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
  address marketAddress;
  ERC20 marketKey;
  ERC20Upgradeable[] rewardTokens;
  uint256 poolId;

  constructor() WithPool() {}

  function setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("Helio-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    flywheel = new FlywheelCore(
      ERC20(heyToken),
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewardsPlugin(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    (address _asset, address _jar) = abi.decode(data, (address, address));

    jar = IJAR(_jar);

    rewardTokens.push(ERC20Upgradeable(address(flywheel.rewardToken())));

    HelioERC4626 jarvisERC4626 = new HelioERC4626();
    jarvisERC4626.initialize(underlyingToken, jar, address(this), rewardTokens);
    plugin = jarvisERC4626;

    initialStrategyBalance = getStrategyBalance();

    deployCErc20PluginRewardsDelegate(address(plugin), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));

    // cToken.approve(address(heyToken), address(flywheelRewards));

    vm.prank(address(cToken));
    ERC20Upgradeable(heyToken).approve(address(flywheelRewards), type(uint256).max);

    marketKey = ERC20(marketAddress);

    flywheel.addStrategyForRewards(marketKey);
    HelioERC4626(address(plugin)).setRewardDestination(marketAddress);
  }

  function deposit(address _owner, uint256 amount) public override {
    vm.startPrank(_owner);
    underlyingToken.approve(address(plugin), amount);
    plugin.deposit(amount, _owner);
    vm.warp(block.timestamp + 10);
    vm.stopPrank();
  }

  function increaseAssetsInVault() public override {
    deal(address(underlyingToken), address(1), 1e18);
    vm.prank(address(1));
    underlyingToken.transfer(address(jar), 1e18);
  }

  function decreaseAssetsInVault() public override {
    vm.prank(address(jar));
    underlyingToken.transfer(address(1), 2e18);
  }

  function getDepositShares() public view override returns (uint256) {
    uint256 amount = jar.balanceOf(address(plugin));
    return amount;
  }

  function getStrategyBalance() public view override returns (uint256) {
    return jar.totalSupply();
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
      address(HelioERC4626(address(plugin)).jar()),
      address(jar),
      string(abi.encodePacked("!jar ", testPreFix))
    );
  }

  // function testAccumulatingRewardsOnDeposit() public {
  //   deposit(address(this), depositAmount / 2);
  //   deal(address(heyToken), address(this), 100e18);
  //   ERC20(heyToken).transfer(address(jar), 100e18);

  //   uint256 expectedReward = jar.pendingRwd(poolId, address(plugin));

  //   deposit(address(this), depositAmount / 2);

  //   assertEq(
  //     ERC20(heyToken).balanceOf(address(plugin)),
  //     expectedReward,
  //     string(abi.encodePacked("!mimoBal ", testPreFix))
  //   );
  // }

  // function testAccumulatingRewardsOnWithdrawal() public {
  //   deposit(address(this), depositAmount);
  //   deal(address(heyToken), address(this), 100e18);
  //   ERC20(heyToken).transfer(address(jar), 100e18);

  //   uint256 expectedReward = jar.pendingRwd(poolId, address(plugin));

  //   plugin.withdraw(1, address(this), address(this));

  //   assertEq(
  //     ERC20(heyToken).balanceOf(address(plugin)),
  //     expectedReward,
  //     string(abi.encodePacked("!mimoBal ", testPreFix))
  //   );
  // }

  // function testClaimRewards() public {
  //   vm.startPrank(address(this));
  //   underlyingToken.approve(marketAddress, depositAmount);
  //   CErc20(marketAddress).mint(depositAmount);
  //   vm.stopPrank();

  //   deal(address(heyToken), address(this), 100e18);
  //   ERC20(heyToken).transfer(address(jar), 100e18);
  //   uint256 expectedReward = jar.pendingRwd(poolId, address(plugin));

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
  //     ERC20(heyToken).balanceOf(address(this)),
  //     expectedReward,
  //     uint256(1000),
  //     string(abi.encodePacked("!mimoBal User ", testPreFix))
  //   );
  //   assertEq(
  //     ERC20(heyToken).balanceOf(address(flywheel)),
  //     0,
  //     string(abi.encodePacked("!mimoBal Flywheel ", testPreFix))
  //   );
  // }
}
