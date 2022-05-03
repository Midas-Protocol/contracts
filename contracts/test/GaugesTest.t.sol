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

    Comptroller comptroller;
    MockERC20 rewardToken;

    FlywheelCore flywheel;
    FlywheelGaugeRewards rewards;
    MockRewardsStream rewardsStream;
    Flywheel3070Booster booster;
    //    FuseFlywheelLensRouter flywheelClaimer;

    function setUp() public {
        stakingController = new StakingController();
        govToken = new TOUCHToken(totalSupply);
        veToken = new VeMDSToken(
            20, // gaugeCycleLength
            10, // incrementFreezeWindow
            address(this),
            Authority(address(0)),
            address(stakingController)
        );
        veToken.setMaxGauges(1);
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
            IFlywheelBooster(address(0)), //booster,
            address(this),
            Authority(address(0))
        );

        rewardsStream = new MockRewardsStream(rewardToken, 10 ether);

        rewards = new FlywheelGaugeRewards(
            flywheel,
            address(this),
            Authority(address(0)),
            veToken,
            IRewardsStream(address(rewardsStream))
        );

        flywheel.setFlywheelRewards(rewards);

//        flywheelClaimer = new FuseFlywheelLensRouter();

    }

    function testMarketGauges(/*uint256 amountToStake*/) public {
        uint256 amountToStake = 1000;
//        vm.assume(amountToStake < totalSupply);
//        vm.assume(amountToStake > 100);

        setUpFlywheel();

        vm.warp(30 days);

        stakingController.stake(amountToStake);

        // advancing 150 days
        vm.warp(block.timestamp + 150 days);

        stakingController.claimAccumulatedVotingPower();

        MockCToken mockCToken = new MockCToken(address(govToken), false);
        veToken.addGauge(address(mockCToken));

        mockCToken.mint(address(this), 2000);

        emit log("ctoken balances");
        emit log_uint(mockCToken.balanceOf(address(this)));
        emit log_uint(mockCToken.totalSupply());
        emit log("ctoken borrow balances");
        emit log_uint(mockCToken.borrowBalanceStored(address(this)));
        emit log_uint(mockCToken.totalBorrows());

        emit log("boosted");
        emit log_uint(booster.boostedBalanceOf(mockCToken, address(this)));
        emit log_uint(booster.boostedTotalSupply(mockCToken));

        //        ERC20 strategy = new MockERC20("test strategy", "TKN", 18);
        flywheel.addStrategyForRewards(mockCToken);//ERC20(address(mock)));

        (uint224 indexBefore, uint32 lastUpdatedTimestampBefore) = flywheel.strategyState(mockCToken);
        emit log_uint(indexBefore);
        emit log_uint(lastUpdatedTimestampBefore);

        //        // add flywheel as rewardsDistributor to call flywheelPreBorrowAction / flywheelPreSupplyAction
//        require(comptroller._addRewardsDistributor(address(flywheel)) == 0, "rewards distributor non-null");

        // seed rewards to flywheel
        rewardToken.mint(address(rewardsStream), 100 ether);

        // preparation for a later call
//        flywheelsToClaim.push(flywheel);

        veToken.incrementGauge(address(mockCToken), uint112(amountToStake / 2));

        vm.warp(block.timestamp + 1 days);

        vm.label(address(veToken), "vetoken");
        // queue rewards and the accrue them
        rewards.queueRewardsForCycle();

        emit log("balance of");
        emit log_uint(rewardToken.balanceOf(address(this)));

        vm.warp(block.timestamp + 8 days);

        flywheel.accrue(mockCToken, address(this));

        emit log("boosted");
        emit log_uint(booster.boostedBalanceOf(mockCToken, address(this)));
        emit log_uint(booster.boostedTotalSupply(mockCToken));

        (uint224 indexAfter, uint32 lastUpdatedTimestampAfter) = flywheel.strategyState(mockCToken);
        emit log_uint(indexAfter);
        emit log_uint(lastUpdatedTimestampAfter);

        emit log("balance of");
        emit log_uint(rewardToken.balanceOf(address(this)));

        require(false, "whatever");
    }
}
