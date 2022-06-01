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

contract MockInterestRateModel is InterestRateModel {
    uint256 public blocksPerYear = 1e6;

    function getBorrowRate(
        uint256,
        uint256,
        uint256
    ) public view override returns (uint256) {
        return 2e12;
    }

    function getSupplyRate(
        uint256,
        uint256,
        uint256,
        uint256
    ) public view override returns (uint256) {
        return 2e12;
    }
}

contract Booster3070SplitTest is DSTest, BNum {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    VeMDSToken veToken;
    uint256 totalSupply = 1e5;
    uint256 rewardsForCycle = 1e5;
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
    MockInterestRateModel interestModel;
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

    // first set up these
    function setUpNoMock() internal {
        underlyingToken = new MockERC20("UnderlyingToken", "UT", 18);
    }

    // then these second
    function setUpPoolAndMarket() internal {
        cErc20Delegate = new CErc20Delegate();
        interestModel = new MockInterestRateModel();
        fusePoolDirectory = new FusePoolDirectory();
        fusePoolDirectory.initialize(false, emptyAddresses);
        fuseAdmin = new FuseFeeDistributor();
        fuseAdmin.initialize(1e16);
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
                interestModel,
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

    /*
    for supplying:
    alice accrues all the rewards for the first half the period = y rewards
    then splitting the other rewards 50/50 for the second half of the period
    (1.5y alice + 0.5y bob) = 30% total rewards

    for borrowing:
    alice accruing all the rewards for the first half of the period = x rewards
    then splitting them 10/90 for the second half of the period
    (1.1x alice + 0.9x bob) = 70% total rewards


    alice gets: 1.1/2 of 30% of the rewards + 1.5/2 of 70% of the rewards = 61% of the rewards
    bob gets: 0.45 * 0.7 * rew + 0.25 * 0.3 * rew = 39% of the rewards
    */
    function testInterestAccrual(/*uint256 borrowAmount*/) public {
//        vm.assume(supplyAmount > 100000000 && supplyAmount < 1000000000);
        uint256 supplyAmount = 1 ether;
        uint256 borrowAmount = supplyAmount / 20;
//        vm.assume(borrowAmount > supplyAmount / 20 && borrowAmount <= supplyAmount / 10);

        setUpNoMock();
        setUpPoolAndMarket();
        setUpStaticRewards(cErc20);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 days);

        // deposit 1 ether as alice and borrow 1000 units
        {
            underlyingToken.mint(alice, supplyAmount);
            vm.startPrank(alice);
            underlyingToken.approve(address(cErc20), supplyAmount);

            bytes4 selector = bytes4(keccak256(bytes("flywheelPreSupplierAction(address,address)")));
            vm.expectCall(address(flywheel), abi.encodeWithSelector(selector, address(cErc20), alice));

            cErc20.mint(supplyAmount);
            cErc20.borrow(borrowAmount);
            vm.stopPrank();
        }

        uint256 aliceSupplyBefore = cErc20.balanceOfUnderlying(alice);
        // advance the time with 1/2 period
        {
            vm.roll(block.number + interestModel.blocksPerYear() / 2);
            vm.warp(block.timestamp + 365.25 days / 2);
        }

        // balanceOfUnderlying accrues the interest
        uint256 aliceSupplyAfter = cErc20.balanceOfUnderlying(alice);
        emit log_uint(aliceSupplyBefore);
        emit log_uint(aliceSupplyAfter);
        assertLt(aliceSupplyBefore, aliceSupplyAfter, "alice should accrue interest on her deposit");

        // accrue the rewards before bob takes part in the supplying/borrowing
        flywheel.accrue(ERC20(address(cErc20)), alice, bob);

        // deposit the other 50 % as bob and contribute to 90 % of the borrowed
        {
            underlyingToken.mint(bob, supplyAmount);
            vm.startPrank(bob);
            underlyingToken.approve(address(cErc20), supplyAmount);
            cErc20.mint(supplyAmount);
            vm.stopPrank();
        }

        // advance the time with 1/2 period
        {
            vm.roll(block.number + interestModel.blocksPerYear() / 2);
            vm.warp(block.timestamp + 365.25 days / 2);
        }

        flywheel.accrue(ERC20(address(cErc20)), alice, bob);

        // claiming the accrued rewards
        flywheel.claimRewards(alice);
        flywheel.claimRewards(bob);

        uint256 aliceRewardsAfter = rewardToken.balanceOf(alice);
        uint256 bobRewardsAfter = rewardToken.balanceOf(bob);

//        emit log_uint((aliceRewardsAfter * 100) / (aliceRewardsAfter + bobRewardsAfter));

        assertTrue(
            100 * aliceRewardsAfter / (aliceRewardsAfter + bobRewardsAfter) == 64
            , "alice should get approx 64% of the total rewards");
    }
}
