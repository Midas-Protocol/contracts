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
import "fuse-flywheel/test/mocks/MockCToken.sol";
import "flywheel-v2/rewards/FlywheelGaugeRewards.sol";
import "flywheel-v2/FlywheelCore.sol";

contract GaugesTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    VeMDSToken veToken;
    TOUCHToken govToken;
    StakingController stakingController;
    uint256 totalSupply = 100_000;
    uint256 rewardsForCycle = 27000;
    address alice = address(0x01);
    address bob = address(0x02);

    Comptroller comptroller;
    MockERC20 rewardToken;
    MockCToken gaugeStrategy;

    FlywheelCore flywheel;
    FlywheelGaugeRewards rewards;
    MockRewardsStream rewardsStream;
    Flywheel3070Booster booster;
    //    FuseFlywheelLensRouter flywheelClaimer;

    function setUp() public {
        stakingController = new StakingController();
        govToken = new TOUCHToken(totalSupply);
        veToken = new VeMDSToken(
            7 days, // gaugeCycleLength
            1 days, // incrementFreezeWindow
            address(this),
            Authority(address(0)),
            address(stakingController)
        );
        veToken.setMaxGauges(1);
        vm.label(address(veToken), "vetoken");
        stakingController.initialize(veToken, govToken);
        govToken.approve(address(stakingController), type(uint256).max);

        Comptroller tempComptroller = new Comptroller(payable(address(this)));
        rewardToken = new MockERC20("test token", "TKN", 18);
    }

    function setUpFlywheel() public {
        emit log("setUpFlywheel");

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
        gaugeStrategy = new MockCToken(address(govToken), false);
        flywheel.addStrategyForRewards(gaugeStrategy);

        vm.prank(address(stakingController));
        veToken.mint(address(this), 1000);

        veToken.addGauge(address(gaugeStrategy));
    }

    function testMarketGauges() public {

        setUpFlywheel();

        vm.warp(block.timestamp + 1 days);

        gaugeStrategy.mint(alice, 4000);
        gaugeStrategy.mint(bob, 6000);

        emit log("ctoken balances");
        emit log_uint(gaugeStrategy.balanceOf(alice));
        emit log_uint(gaugeStrategy.balanceOf(bob));
        emit log_uint(gaugeStrategy.totalSupply());
        emit log("ctoken borrow balances");
        emit log_uint(gaugeStrategy.borrowBalanceStored(alice));
        emit log_uint(gaugeStrategy.borrowBalanceStored(bob));
        emit log_uint(gaugeStrategy.totalBorrows());

        emit log("boosted");
        emit log_uint(booster.boostedBalanceOf(gaugeStrategy, alice));
        emit log_uint(booster.boostedBalanceOf(gaugeStrategy, bob));
        emit log_uint(booster.boostedTotalSupply(gaugeStrategy));

        // first set up the gauge voting before the freeze window comes
        veToken.incrementGauge(address(gaugeStrategy), 1000);

        vm.warp(block.timestamp + 6 days);

        printQueuedRewards();
        emit log_uint(veToken.getGaugeCycleEnd());
        emit log_uint(block.timestamp);

        emit log("queue rewards and then accrue them");
        // transfers the reward tokens from the stream to the rewards contract
        rewards.queueRewardsForCycle();
        printQueuedRewards();

        printRewardBalances();

        vm.warp(block.timestamp + 8 days);

//        rewards.queueRewardsForCycle();

        // rewards are accrued only when the cycle is over
        //
        flywheel.accrue(gaugeStrategy, alice);
        flywheel.accrue(gaugeStrategy, bob);

        printQueuedRewards();

        emit log("boosted");
        emit log_uint(booster.boostedBalanceOf(gaugeStrategy, alice));
        emit log_uint(booster.boostedBalanceOf(gaugeStrategy, bob));
        emit log_uint(booster.boostedTotalSupply(gaugeStrategy));

        printRewardBalances();

        vm.warp(block.timestamp + 1 days);

        emit log("claiming the accrued rewards");
        flywheel.claimRewards(alice);
        flywheel.claimRewards(bob);

        printRewardBalances();

        require(false, "whatever");
    }

    function printRewardBalances() internal {
        emit log("balance of");
        emit log_uint(rewardToken.balanceOf(alice));
        emit log_uint(rewardToken.balanceOf(bob));
    }

    function printQueuedRewards() internal {
        (
            uint112 priorCycleRewards,
            uint112 cycleRewards,
            uint32 storedCycle
        ) = rewards.gaugeQueuedRewards(gaugeStrategy);

        emit log("queued rewards: prior cycle rew, cycle rew, stored cycle");
        emit log_uint(priorCycleRewards);
        emit log_uint(cycleRewards);
        emit log_uint(storedCycle);
    }
}
