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


contract Booster3070SplitTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    VeMDSToken veToken;
    uint256 totalSupply = 100_000;
    uint256 rewardsForCycle = 27000;
    address alice = address(0x10);
    address bob = address(0x20);

    MockERC20 rewardToken;
    MockCToken gaugeStrategy;

    FlywheelCore flywheel;
    FlywheelGaugeRewards rewards;
    MockRewardsStream rewardsStream;

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

        rewardToken = new MockERC20("test token", "TKN", 18);
        booster = new Flywheel3070Booster();
        flywheel = new FlywheelCore(
            rewardToken,
            IFlywheelRewards(address(0)),
            booster,
            address(this),
            Authority(address(0))
        );

        FlywheelStaticRewards staticRewards = new FlywheelStaticRewards(flywheel, address(this), Authority(address(0)));
        flywheel.setFlywheelRewards(staticRewards);
        flywheel.addStrategyForRewards(ERC20(address(cErc20)));

        // add flywheel as rewardsDistributor to call flywheelPreBorrowAction / flywheelPreSupplyAction
        require(comptroller._addRewardsDistributor(address(flywheel)) == 0);

        // seed rewards to flywheel
        rewardToken.mint(address(staticRewards), 100 ether);
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
        vm.assume(alice != address(0));
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
        assertEq(aliceRewardsAfter, 5130, "wrong end rewards balance for alice");

        uint256 bobRewardsAfter = rewardToken.balanceOf(bob);
        assertEq(aliceRewardsAfter + bobRewardsAfter, rewardsForCycle, "total rewards claimed should equal the rewards for the cycle");
    }

    /*
    alice accruing all the rewards for the first half of the year = x rewards
    then splitting them 10/90 for the second half of the year = 0.1x rewards
    */
    function testInterestAccrual() public {
        setUpNoMock();
        setUpPoolAndMarket();

        uint256 accrualBlockNumberBefore = cErc20.accrualBlockNumber();
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        uint256 _amount = 1 ether;
//        comptroller.enterMarkets(markets);

        // deposit 10% of the total as alice
        {
            underlyingToken.mint(alice, _amount);
            vm.startPrank(alice);
            underlyingToken.approve(address(cErc20), _amount);
            cErc20.mint(_amount);
            cErc20.borrow(10);
            vm.stopPrank();
        }

        uint256 totalBorrowsBefore = cErc20.totalBorrows();
        // advance the time with 1/2 year
        vm.roll(block.number + interestModel.blocksPerYear() / 2 + 1);
        cErc20.accrueInterest();

        // deposit the other 90% as bob
        {
            underlyingToken.mint(bob, _amount);
            vm.startPrank(bob);
            underlyingToken.approve(address(cErc20), _amount);
            cErc20.mint(_amount);
            cErc20.borrow(90);
            vm.stopPrank();
        }

        // advance the time with 1/2 year
        vm.roll(block.number + interestModel.blocksPerYear() / 2 + 1);
        cErc20.accrueInterest();

        flywheel.accrue(ERC20(address(cErc20)), alice);
        flywheel.accrue(ERC20(address(cErc20)), bob);

        // claiming the accrued rewards
        flywheel.claimRewards(alice);
        flywheel.claimRewards(bob);

        uint256 aliceRewardsAfter = rewardToken.balanceOf(alice);
        uint256 bobRewardsAfter = rewardToken.balanceOf(bob);

        emit log_uint(aliceRewardsAfter);
        emit log_uint(bobRewardsAfter);

        assertTrue(false, "whatever");
    }
}
