// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { WithPool } from "../helpers/WithPool.sol";
import { BaseTest } from "../config/BaseTest.t.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { MidasERC4626, ArrakisERC4626, IGuniPool } from "../../midas/strategies/ArrakisERC4626.sol";
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

contract ArrakisERC4626Test is AbstractERC4626Test {
  using FixedPointMathLib for uint256;

  IGuniPool pool;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewardsPlugin flywheelRewards;
  address mimoToken = 0xADAC33f543267c4D59a8c299cF804c303BC3e4aC;
  address marketAddress;
  ERC20 marketKey;
  ERC20Upgradeable[] rewardTokens;

  constructor() WithPool() {}

  function setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("arrakis-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    flywheel = new FlywheelCore(
      ERC20(mimoToken),
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewardsPlugin(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    (address _asset, address _pool) = abi.decode(data, (address, address));

    pool = IGuniPool(_pool);

    rewardTokens.push(ERC20Upgradeable(address(flywheel.rewardToken())));

    ArrakisERC4626 arrakisERC4626 = new ArrakisERC4626();
    arrakisERC4626.initialize(ERC20Upgradeable(address(underlyingToken)), flywheel, pool, address(this), rewardTokens);

    plugin = arrakisERC4626;
    initialStrategyBalance = pool.totalStake();

    deployCErc20PluginRewardsDelegate(address(plugin), 0.9e18);
    marketAddress = address(comptroller.cTokensByUnderlying(address(underlyingToken)));
    CErc20PluginRewardsDelegate cToken = CErc20PluginRewardsDelegate(marketAddress);
    cToken._setImplementationSafe(address(cErc20PluginRewardsDelegate), false, abi.encode(address(plugin)));
    assertEq(address(cToken.plugin()), address(plugin));

    cToken.approve(address(mimoToken), address(flywheelRewards));

    marketKey = ERC20(marketAddress);

    flywheel.addStrategyForRewards(marketKey);
    ArrakisERC4626(address(plugin)).setRewardDestination(marketAddress);
  }

  function increaseAssetsInVault() public override {
    deal(address(underlyingToken), address(1), 1e18);
    vm.prank(address(1));
    underlyingToken.transfer(address(pool), 1e18);
  }

  function decreaseAssetsInVault() public override {
    vm.prank(address(pool));
    underlyingToken.transfer(address(1), 2e18);
  }

  function getDepositShares() public view override returns (uint256) {
    return pool.stake(address(plugin));
  }

  function getStrategyBalance() public view override returns (uint256) {
    return pool.totalStake();
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
      address(ArrakisERC4626(address(plugin)).pool()),
      address(pool),
      string(abi.encodePacked("!pool ", testPreFix))
    );
  }

  function testAccumulatingRewardsOnDeposit() public {
    deposit(address(this), depositAmount / 2);
    deal(address(mimoToken), address(this), 100e18);
    ERC20(mimoToken).transfer(address(pool), 100e18);

    uint256 expectedReward = pool.pendingMIMO(address(plugin));

    deposit(address(this), depositAmount / 2);

    assertEq(
      ERC20(mimoToken).balanceOf(address(plugin)),
      expectedReward,
      string(abi.encodePacked("!mimoBal ", testPreFix))
    );
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    deposit(address(this), depositAmount);
    deal(address(mimoToken), address(this), 100e18);
    ERC20(mimoToken).transfer(address(pool), 100e18);

    uint256 expectedReward = pool.pendingMIMO(address(plugin));

    plugin.withdraw(1, address(this), address(this));

    assertEq(
      ERC20(mimoToken).balanceOf(address(plugin)),
      expectedReward,
      string(abi.encodePacked("!mimoBal ", testPreFix))
    );
  }

  function testClaimRewards() public {
    vm.startPrank(address(this));
    underlyingToken.approve(marketAddress, depositAmount);
    CErc20(marketAddress).mint(depositAmount);
    vm.stopPrank();

    deal(address(underlyingToken), address(this), depositAmount);
    deposit(address(this), depositAmount);

    deal(address(mimoToken), address(this), 100e18);
    ERC20(mimoToken).transfer(address(pool), 100e18);
    uint256 expectedReward = pool.pendingMIMO(address(plugin));

    (uint32 mimoStart, uint32 mimoEnd, uint192 mimoReward) = flywheelRewards.rewardsCycle(
      ERC20(address(marketAddress))
    );

    emit log_named_uint("mimoReward", mimoReward);

    // Rewards can be transfered in the next cycle
    assertEq(mimoEnd, 0, string(abi.encodePacked("!mimoEnd ", testPreFix)));

    // Reward amount is still 0
    assertEq(mimoReward, 0, string(abi.encodePacked("!mimoReward ", testPreFix)));

    vm.warp(block.timestamp + 150);
    vm.roll(20);

    // Call accrue as proxy for withdraw/deposit to claim rewards
    flywheel.accrue(ERC20(marketAddress), address(this));

    // Accrue rewards to send rewards to flywheelRewards
    flywheel.accrue(ERC20(marketAddress), address(this));

    (mimoStart, mimoEnd, mimoReward) = flywheelRewards.rewardsCycle(ERC20(address(marketAddress)));

    emit log_named_uint("mimoReward after", mimoReward);

    // Rewards can be transfered in the next cycle
    assertGt(mimoEnd, 1000000000, string(abi.encodePacked("!2.mimoEnd ", testPreFix)));
    assertApproxEqAbs(
      mimoReward,
      expectedReward,
      uint256(1000),
      string(abi.encodePacked("!2.mimoReward ", testPreFix))
    );

    vm.warp(block.timestamp + 150);
    vm.roll(20);

    (mimoStart, mimoEnd, mimoReward) = flywheelRewards.rewardsCycle(ERC20(address(marketAddress)));

    emit log_named_uint("mimoReward after 111", mimoReward);

    flywheel.accrue(ERC20(marketAddress), address(this));

    // Claim Rewards for the user
    flywheel.claimRewards(address(this));

    assertApproxEqAbs(
      ERC20(mimoToken).balanceOf(address(this)),
      expectedReward,
      uint256(1000),
      string(abi.encodePacked("!mimoBal User ", testPreFix))
    );
    assertEq(
      ERC20(mimoToken).balanceOf(address(flywheel)),
      0,
      string(abi.encodePacked("!mimoBal Flywheel ", testPreFix))
    );
  }
}
