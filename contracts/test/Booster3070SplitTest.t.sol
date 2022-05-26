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

// no mock imports
import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";
import { CErc20 } from "../compound/CErc20.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { MockPriceOracle } from "../oracles/1337/MockPriceOracle.sol";
import { ComptrollerInterface } from "../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../compound/InterestRateModel.sol";
import { CToken } from "../compound/CToken.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { FlywheelStaticRewards } from "flywheel-v2/rewards/FlywheelStaticRewards.sol";
import "fuse-flywheel/FuseFlywheelCore.sol";


contract Booster3070SplitTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    VeMDSToken veToken;
    uint256 totalSupply = 100_000;
    uint256 rewardsForCycle = 27000;
    address alice = address(0x10);
    address bob = address(0x20);

    MockERC20 rewardToken;
    MockCToken gaugeStrategy;

    FuseFlywheelCore flywheel;
    FlywheelGaugeRewards rewards;
    MockRewardsStream rewardsStream;
    FlywheelStaticRewards staticRewards;
    Flywheel3070Booster booster;

    // no mock testing
    WhitePaperInterestRateModel interestModel;
    Comptroller comptroller;
    CErc20 cErc20;
    FuseFeeDistributor fuseAdmin;
    FusePoolDirectory fusePoolDirectory;
    CErc20Delegate cErc20Delegate;
    MockERC20 underlyingToken;

    address[] emptyAddresses;
    address[] newUnitroller;
    bool[] falseBoolArray;
    bool[] trueBoolArray;
    address[] newImplementation;

    // first set up these
    function setUpNoMock() internal {
        interestModel = new WhitePaperInterestRateModel(2343665, 1e18, 1e18);
        fuseAdmin = new FuseFeeDistributor();
        fuseAdmin.initialize(1e16);
        fusePoolDirectory = new FusePoolDirectory();
        fusePoolDirectory.initialize(false, emptyAddresses);
        cErc20Delegate = new CErc20Delegate();
        underlyingToken = new MockERC20("UnderlyingToken", "UT", 18);
    }

    // then these second
    function setUpPoolAndMarket() internal {
        MockPriceOracle priceOracle = new MockPriceOracle(10);
        emptyAddresses.push(address(0));
        Comptroller tempComptroller = new Comptroller(payable(fuseAdmin));
        newUnitroller.push(address(tempComptroller));
        trueBoolArray.push(true);
        falseBoolArray.push(false);
        fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);
        (uint256 index, address comptrollerAddress) = fusePoolDirectory.deployPool(
            "TestPool",
            address(tempComptroller),
            abi.encode(payable(address(fuseAdmin))),
            false,
            0.1e18,
            1.1e18,
            address(priceOracle)
        );

        Unitroller(payable(comptrollerAddress))._acceptAdmin();
        comptroller = Comptroller(comptrollerAddress);

        newImplementation.push(address(cErc20Delegate));
        fuseAdmin._editCErc20DelegateWhitelist(emptyAddresses, newImplementation, falseBoolArray, trueBoolArray);
        vm.roll(1);
        comptroller._deployMarket(
            false,
            abi.encode(
                address(underlyingToken),
                ComptrollerInterface(comptrollerAddress),
                payable(address(fuseAdmin)),
                InterestRateModel(address(interestModel)),
                "CUnderlyingToken",
                "CUT",
                address(cErc20Delegate),
                "",
                uint256(1),
                uint256(0)
            ),
            0.9e18
        );

        CToken[] memory allMarkets = comptroller.getAllMarkets();
        cErc20 = CErc20(address(allMarkets[allMarkets.length - 1]));
    }

    function setUpStaticRewards(CErc20 _cErc20) internal {
        rewardToken = new MockERC20("test token", "TKN", 18);
        booster = new Flywheel3070Booster();
        flywheel = new FuseFlywheelCore(
            rewardToken,
            IFlywheelRewards(address(0)), // it's ok, set later
            booster,
            address(this),
            Authority(address(0))
        );

        staticRewards = new FlywheelStaticRewards(flywheel, address(this), Authority(address(0)));

        // seed rewards to flywheel
        rewardToken.mint(address(staticRewards), 100 ether);

        flywheel.setFlywheelRewards(staticRewards);
        flywheel.addStrategyForRewards(ERC20(address(_cErc20)));

        // add flywheel as rewardsDistributor to call flywheelPreBorrowAction / flywheelPreSupplyAction
        require(comptroller._addRewardsDistributor(address(flywheel)) == 0);

        // Start reward distribution at 1 token per second
        staticRewards.setRewardsInfo(
            ERC20(address(_cErc20)),
            FlywheelStaticRewards.RewardsInfo({ rewardsPerSecond: 1000, rewardsEndTimestamp: 0 })
        );
    }

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

        flywheel = new FuseFlywheelCore(
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
        vm.assume(alice != address(0));
        vm.assume(alice != bob);
        vm.assume(votingPower > 0);
        veToken.mint(address(this), votingPower);

        // Alice contributes 40% of the supply
        gaugeStrategy.mint(alice, 4000);
        // the rest is supplied by Bob
        gaugeStrategy.mint(bob, 6000);

        // Alice contributes to 10% of the borrowed
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
        assertEq(aliceRewardsAfter, 5130, "wrong end rewards balance for alice");

        uint256 bobRewardsAfter = rewardToken.balanceOf(bob);
        assertEq(aliceRewardsAfter + bobRewardsAfter, rewardsForCycle, "total rewards claimed should equal the rewards for the cycle");
    }

    /*
    for borrowing:
    alice accruing all the rewards for the first half of the year = x rewards
    then splitting them 10/90 for the second half of the year = 0.1x rewards
    (1.1x alice + 0.9x bob) = 0.3 total rewards

    for supplying:
    alice accrues all the rewards for the first half the year = y rewards
    then splitting the other rewards 50/50 for the second half of the year = 0.5 rewards
    (1.5y alice + 0.5y bob) = 0.7 total rewards


    alice gets: 1.1/2 of 30% of the rewards + 1.5/2 of 70% of the rewards = 0.69 rew
    bob gets: 0.45 * 0.3 * rew + 0.25 * 0.7 * rew = 0.31 rew
    */
    function testInterestAccrual() public {
        setUpNoMock();
        setUpPoolAndMarket();
        setUpStaticRewards(cErc20);

        uint256 accrualBlockNumberBefore = cErc20.accrualBlockNumber();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 days);

        {
            (uint224 index, uint32 lastUpdatedTimestamp) = flywheel.strategyState(ERC20(address(cErc20)));
            emit log("strategy state index");
            emit log_uint(index);
            emit log("strategy state lastUpdatedTimestamp");
            emit log_uint(lastUpdatedTimestamp);
            vm.prank(address(flywheel));
            emit log_uint(staticRewards.getAccruedRewards(ERC20(address(cErc20)), lastUpdatedTimestamp));
        }

        uint256 _amount = 1 ether;

        // deposit 10% of the total as alice
        {
            underlyingToken.mint(alice, _amount);
            vm.startPrank(alice);
            underlyingToken.approve(address(cErc20), _amount);
            cErc20.mint(_amount);
            cErc20.borrow(1000);
            vm.stopPrank();
        }

        uint256 totalBorrowsBefore = cErc20.totalBorrows();
        // advance the time with 1/2 year
//        vm.roll(block.number + interestModel.blocksPerYear() / 2 + 1);
        vm.warp(block.timestamp + 178 days);
        cErc20.accrueInterest();

        // deposit the other 50% as bob and contribute as 90% of the borrowed
        {
            underlyingToken.mint(bob, _amount);
            vm.startPrank(bob);
            underlyingToken.approve(address(cErc20), _amount);
            cErc20.mint(_amount);
            cErc20.borrow(9000);
            vm.stopPrank();
        }

        {
            (uint224 index, uint32 lastUpdatedTimestamp) = flywheel.strategyState(ERC20(address(cErc20)));
            emit log("strategy state index");
            emit log_uint(index);
            emit log("strategy state lastUpdatedTimestamp");
            emit log_uint(lastUpdatedTimestamp);
        }

        // advance the time with 1/2 year
//        vm.roll(block.number + interestModel.blocksPerYear() / 2 + 1);
        vm.warp(block.timestamp + 178 days);
        cErc20.accrueInterest();

        {
            (uint224 index, uint32 lastUpdatedTimestamp) = flywheel.strategyState(ERC20(address(cErc20)));
            emit log("strategy state index");
            emit log_uint(index);
            emit log("strategy state lastUpdatedTimestamp");
            emit log_uint(lastUpdatedTimestamp);
        }

        emit log("current timestamp");
        emit log_uint(block.timestamp);

        flywheel.accrue(ERC20(address(cErc20)), alice, bob);

        {
            emit log("comp accrued");
            uint256 aliceCompAfter = flywheel.compAccrued(alice);
            uint256 bobCompAfter = flywheel.compAccrued(bob);

            emit log_uint(aliceCompAfter);
            emit log_uint(bobCompAfter);
        }

        // claiming the accrued rewards
        flywheel.claimRewards(alice);
        flywheel.claimRewards(bob);

        {
            emit log("rewards balance after");
            uint256 aliceRewardsAfter = rewardToken.balanceOf(alice);
            uint256 bobRewardsAfter = rewardToken.balanceOf(bob);

            emit log_uint(aliceRewardsAfter);
            emit log_uint(bobRewardsAfter);
        } // this prints 13/90 of the rewards for alice

        assertTrue(false, "whatever");
    }
}
