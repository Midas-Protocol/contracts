// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockRewardsStream } from "flywheel-v2/test/mocks/MockRewardsStream.sol";
import { Comptroller } from "../compound/Comptroller.sol";

import "../governance/VeMDSToken.sol";
import "../governance/StakingController.sol";
import "../governance/Flywheel3070Booster.sol";
import { MockCToken } from "./mocks/MockCToken.sol";
import "flywheel-v2/rewards/FlywheelGaugeRewards.sol";
import "flywheel-v2/FlywheelCore.sol";

contract Booster3070SplitTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    VeMDSToken veToken;
    uint256 totalSupply = 100_000;
    uint256 rewardsForCycle = 27000;

    MockERC20 rewardToken;
    MockCToken gaugeStrategy;

    FlywheelCore flywheel;
    FlywheelGaugeRewards rewards;
    MockRewardsStream rewardsStream;

    Flywheel3070Booster booster;

    function setUp() public {
        veToken = new VeMDSToken(
            7 days, // gaugeCycleLength
            1 days, // incrementFreezeWindow
            address(this),
            Authority(address(0)),
            address(this) // staking controller
        );
        veToken.setMaxGauges(1);
        vm.label(address(veToken), "vetoken");

        rewardToken = new MockERC20("test token", "TKN", 18);
        booster = new Flywheel3070Booster();

        flywheel = new FlywheelCore(
            rewardToken,
            IFlywheelRewards(address(0)),
            booster,
            address(this),
            Authority(address(0))
        );

        rewardsStream = new MockRewardsStream(rewardToken, rewardsForCycle);

        rewards = new FlywheelGaugeRewards(
            flywheel,
            address(this),
            Authority(address(0)),
            veToken,
            IRewardsStream(address(rewardsStream))
        );

        flywheel.setFlywheelRewards(rewards);
        // seed rewards to flywheel
        rewardToken.mint(address(rewardsStream), rewardsForCycle * 3);

        gaugeStrategy = new MockCToken(address(0), false);
        flywheel.addStrategyForRewards(gaugeStrategy);
        veToken.addGauge(address(gaugeStrategy));
    }

    function testMarketGauges(address alice, address bob, uint112 votingPower) public {
        vm.assume(alice != bob);
        vm.assume(votingPower > 0);
        veToken.mint(address(this), votingPower);

        // Alice contributes 40% of the supply
        gaugeStrategy.mint(alice, 4000);
        // the rest is supplied by Bob
        gaugeStrategy.mint(bob, 6000);

        // Alice contributes 10% of the borrowed
        gaugeStrategy.borrow(alice, 135);
        // the rest is borrowed by Bob
        gaugeStrategy.borrow(bob, 1215);

        // first set up the gauge voting before the freeze window comes
        veToken.incrementGauge(address(gaugeStrategy), votingPower);

        // advance the time so a week has passed since the gauge cycle has started
        // in order to start a new cycle
        vm.warp(block.timestamp + 7 days);

        // transfers the reward tokens from the stream to the rewards contract
        rewards.queueRewardsForCycle();

        uint256 aliceRewardsBefore = rewardToken.balanceOf(alice);
        assertEq(aliceRewardsBefore, 0, "alice should not have any rewards in the beginning");

        // rewards can be accrued only when the cycle is over
        vm.warp(block.timestamp + 8 days);

        flywheel.accrue(gaugeStrategy, alice);
        flywheel.accrue(gaugeStrategy, bob);

        // advance the time to make sure only the accrued rewards are claimed
        vm.warp(block.timestamp + 1 days);

        // claiming the accrued rewards
        flywheel.claimRewards(alice);
        flywheel.claimRewards(bob);

        uint256 aliceRewardsAfter = rewardToken.balanceOf(alice);
        assertEq(aliceRewardsAfter, 5130, "alice should not have any rewards in the beginning");

        uint256 bobRewardsAfter = rewardToken.balanceOf(bob);
        assertEq(aliceRewardsAfter + bobRewardsAfter, rewardsForCycle, "total rewards claimed should equal the rewards for the cycle");
    }
}
