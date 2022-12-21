// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { FlywheelStaticRewards } from "flywheel-v2/rewards/FlywheelStaticRewards.sol";
import { MidasFlywheelLensRouter, CErc20Token } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";
import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";

import { CTokenInterface, CTokenExtensionInterface } from "../compound/CTokenInterfaces.sol";
import { CErc20 } from "../compound/CErc20.sol";
import { CToken } from "../compound/CToken.sol";
import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { ComptrollerFirstExtension } from "../compound/ComptrollerFirstExtension.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20Delegator } from "../compound/CErc20Delegator.sol";
import { ComptrollerInterface } from "../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../compound/InterestRateModel.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { MockPriceOracle } from "../oracles/1337/MockPriceOracle.sol";
import { CTokenFirstExtension, DiamondExtension } from "../compound/CTokenFirstExtension.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract LiquidityMiningTest is BaseTest {
  MockERC20 underlyingToken;
  MockERC20 rewardToken;

  WhitePaperInterestRateModel interestModel;
  Comptroller comptroller;
  CErc20Delegate cErc20Delegate;
  CErc20 cErc20;
  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;

  MidasFlywheel flywheel;
  FlywheelStaticRewards rewards;
  MidasFlywheelLensRouter flywheelClaimer;

  address user = address(1337);

  uint8 baseDecimal;
  uint8 rewardDecimal;

  address[] markets;
  address[] emptyAddresses;
  address[] newUnitroller;
  bool[] falseBoolArray;
  bool[] trueBoolArray;
  address[] newImplementation;
  MidasFlywheelCore[] flywheelsToClaim;

  function setUpBaseContracts(uint8 _baseDecimal, uint8 _rewardDecimal) public {
    baseDecimal = _baseDecimal;
    rewardDecimal = _rewardDecimal;
    underlyingToken = new MockERC20("UnderlyingToken", "UT", baseDecimal);
    rewardToken = new MockERC20("RewardToken", "RT", rewardDecimal);
    interestModel = new WhitePaperInterestRateModel(2343665, 1 * 10**baseDecimal, 1 * 10**baseDecimal);
    fuseAdmin = new FuseFeeDistributor();
    fuseAdmin.initialize(1 * 10**(baseDecimal - 2));
    fusePoolDirectory = new FusePoolDirectory();
    fusePoolDirectory.initialize(false, emptyAddresses);
    cErc20Delegate = new CErc20Delegate();
    DiamondExtension[] memory cErc20DelegateExtensions = new DiamondExtension[](1);
    cErc20DelegateExtensions[0] = new CTokenFirstExtension();
    fuseAdmin._setCErc20DelegateExtensions(address(cErc20Delegate), cErc20DelegateExtensions);
  }

  function setUpPoolAndMarket() public {
    MockPriceOracle priceOracle = new MockPriceOracle(10);
    emptyAddresses.push(address(0));
    Comptroller tempComptroller = new Comptroller(payable(fuseAdmin));
    newUnitroller.push(address(tempComptroller));
    trueBoolArray.push(true);
    falseBoolArray.push(false);
    fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);
    DiamondExtension[] memory extensions = new DiamondExtension[](1);
    extensions[0] = new ComptrollerFirstExtension();
    fuseAdmin._setComptrollerExtensions(address(tempComptroller), extensions);
    (, address comptrollerAddress) = fusePoolDirectory.deployPool(
      "TestPool",
      address(tempComptroller),
      abi.encode(payable(address(fuseAdmin))),
      false,
      0.1e18,
      1.1e18,
      address(priceOracle)
    );

    Unitroller(payable(comptrollerAddress))._acceptAdmin();
    comptroller = Comptroller(payable(comptrollerAddress));

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

    CTokenInterface[] memory allMarkets = comptroller.asComptrollerFirstExtension().getAllMarkets();
    cErc20 = CErc20(address(allMarkets[allMarkets.length - 1]));
  }

  function setUpFlywheel() public {
    flywheel = new MidasFlywheel();
    flywheel.initialize(rewardToken, FlywheelStaticRewards(address(0)), IFlywheelBooster(address(0)), address(this));
    rewards = new FlywheelStaticRewards(FlywheelCore(address(flywheel)), address(this), Authority(address(0)));
    flywheel.setFlywheelRewards(rewards);

    flywheelClaimer = new MidasFlywheelLensRouter();

    flywheel.addStrategyForRewards(ERC20(address(cErc20)));

    // add flywheel as rewardsDistributor to call flywheelPreBorrowAction / flywheelPreSupplyAction
    require(comptroller._addRewardsDistributor(address(flywheel)) == 0);

    // seed rewards to flywheel
    rewardToken.mint(address(rewards), 100 * 10**rewardDecimal);

    // Start reward distribution at 1 token per second
    rewards.setRewardsInfo(
      ERC20(address(cErc20)),
      FlywheelStaticRewards.RewardsInfo({ rewardsPerSecond: uint224(1 * 10**rewardDecimal), rewardsEndTimestamp: 0 })
    );

    // preparation for a later call
    flywheelsToClaim.push(MidasFlywheelCore(address(flywheel)));
  }

  function _initialize(uint8 baseDecimal, uint8 rewardDecimal) internal {
    setUpBaseContracts(baseDecimal, rewardDecimal);
    setUpPoolAndMarket();
    setUpFlywheel();
    deposit(1 * 10**baseDecimal);
    vm.warp(block.timestamp + 1);
  }

  function deposit(uint256 _amount) public {
    underlyingToken.mint(user, _amount);
    vm.startPrank(user);
    underlyingToken.approve(address(cErc20), _amount);
    comptroller.enterMarkets(markets);
    cErc20.mint(_amount);
    vm.stopPrank();
  }

  function _testIntegration() internal {
    uint256 percentFee = flywheel.performanceFee();
    uint224 percent100 = 100e16; //flywheel.ONE();

    CTokenExtensionInterface asExtension = cErc20.asCTokenExtensionInterface();

    // store expected rewards per token (1 token per second over total supply)
    uint256 rewardsPerTokenPlusFee = (1 * 10**rewardDecimal * 1 * 10**baseDecimal) / asExtension.totalSupply();
    uint256 rewardsPerTokenForFee = (rewardsPerTokenPlusFee * percentFee) / percent100;
    uint256 rewardsPerToken = rewardsPerTokenPlusFee - rewardsPerTokenForFee;

    // store expected user rewards (user balance times reward per second over 1 token)
    uint256 userRewards = (rewardsPerToken * asExtension.balanceOf(user)) / (1 * 10**baseDecimal);

    ERC20 asErc20 = ERC20(address(asExtension));
    // accrue rewards and check against expected
    assertEq(flywheel.accrue(asErc20, user), userRewards, "!accrue amount");

    // check market index
    (uint224 index, ) = flywheel.strategyState(asErc20);
    assertEq(index, 10**rewardDecimal + rewardsPerToken, "!index");

    // claim and check user balance
    flywheelClaimer.getUnclaimedRewardsForMarket(user, asErc20, flywheelsToClaim, trueBoolArray);
    assertEq(rewardToken.balanceOf(user), userRewards, "!user rewards");

    // mint more tokens by user and rerun test
    deposit(1e6 * 10**baseDecimal);

    // for next test, advance 10 seconds instead of 1 (multiply expectations by 10)
    vm.warp(block.timestamp + 10);

    uint256 rewardsPerToken2PlusFee = (10 * 10**rewardDecimal * 1 * 10**baseDecimal) / asExtension.totalSupply();
    uint256 rewardsPerToken2ForFee = (rewardsPerToken2PlusFee * percentFee) / percent100;
    uint256 rewardsPerToken2 = rewardsPerToken2PlusFee - rewardsPerToken2ForFee;

    uint256 userRewards2 = (rewardsPerToken2 * asExtension.balanceOf(user)) / (1 * 10**baseDecimal);

    // accrue all unclaimed rewards and claim them
    flywheelClaimer.getUnclaimedRewardsForMarket(user, asErc20, flywheelsToClaim, trueBoolArray);

    emit log_named_uint("userRewards", userRewards);
    emit log_named_uint("userRewards2", userRewards2);
    // user balance should accumulate from both rewards
    assertEq(rewardToken.balanceOf(user), userRewards + userRewards2, "balance mismatch");
  }

  function testIntegrationRewardStandard(uint8 i, uint8 j) public {
    vm.assume(i > 1);
    vm.assume(j > 1);
    vm.assume(i < 19);
    vm.assume(j < 19);

    _initialize(i, j);
    _testIntegration();
  }
}
