// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";
import "../governance/VeMDSToken.sol";
import "../governance/StakingController.sol";
import "../utils/TOUCHToken.sol";

contract StakingTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  VeMDSToken veToken;
  TOUCHToken govToken;
  StakingController stakingController;

  event Transfer(address indexed from, address indexed to, uint256 amount);

  uint256 totalSupply = 100_000;

  function setUp() public {
    stakingController = new StakingController();
    govToken = new TOUCHToken(totalSupply);
    veToken = new VeMDSToken(
      2, // gaugeCycleLength
      1, // incrementFreezeWindow
      address(this),
      Authority(address(0)),
      address(stakingController)
    );
    stakingController.initialize(veToken, govToken);
    govToken.approve(address(stakingController), type(uint256).max);
  }

  function testStaking(uint256 amountToStake) public {
    vm.assume(amountToStake > 0 && amountToStake < totalSupply);

    vm.warp(30 days);

    uint256 totalStakedBefore = stakingController.totalStaked();
    uint256 stakerBalanceBefore = govToken.balanceOf(address(this));
    uint256 contractBalanceBefore = govToken.balanceOf(address(stakingController));
    stakingController.stake(amountToStake);

    {
      uint256 totalStakedAfter = stakingController.totalStaked();
      uint256 stakerBalanceAfter = govToken.balanceOf(address(this));
      uint256 contractBalanceAfter = govToken.balanceOf(address(stakingController));

      assert(stakerBalanceBefore - stakerBalanceAfter == amountToStake);
      assert(contractBalanceAfter - contractBalanceBefore == amountToStake);
      assert(totalStakedAfter - totalStakedBefore == amountToStake);
    }

    // advancing 1 day
    vm.warp(block.timestamp + 1 days);
    stakingController.claimAccumulatedVotingPower();
    assert(veToken.balanceOf(address(this)) == amountToStake * 1000 / 297625);

    {
      uint256 totalStakedAfter = stakingController.totalStaked();
      uint256 stakerBalanceAfter = govToken.balanceOf(address(this));
      uint256 contractBalanceAfter = govToken.balanceOf(address(stakingController));

      assert(stakerBalanceBefore - stakerBalanceAfter == amountToStake);
      assert(contractBalanceAfter - contractBalanceBefore == amountToStake);
      assert(totalStakedAfter - totalStakedBefore == amountToStake);
    }

    // advancing 7142 hours
    vm.warp(block.timestamp + 7142 hours);
    stakingController.claimAccumulatedVotingPower();
    assert(veToken.balanceOf(address(this)) == amountToStake);
  }

  function testSelfUnstaking(uint256 amountToStake, uint256 amountToUnstake) public {
    vm.assume(amountToStake > amountToUnstake && amountToStake < totalSupply);
    vm.assume(amountToUnstake > 0 && amountToUnstake < totalSupply);

    vm.warp(30 days);

    stakingController.stake(amountToStake);

    // advancing 1 day
    vm.warp(block.timestamp + 1 days);
    assert(veToken.balanceOf(address(this)) == 0);

    stakingController.claimAccumulatedVotingPower();
    assert(veToken.balanceOf(address(this)) == amountToStake * 1000 / 297625);

    uint256 stakerBalanceBefore = govToken.balanceOf(address(this));
    uint256 contractBalanceBefore = govToken.balanceOf(address(stakingController));
    uint256 totalStakedBefore = stakingController.totalStaked();

    uint256 allTheVp = veToken.balanceOf(address(this));
    stakingController.declareUnstake(amountToUnstake);
    vm.warp(block.timestamp + 7 days);
//    vm.expectEmit(true, true, true, false);
//    emit Transfer(address(this), address(0), allTheVp);
    stakingController.unstake(address(this));

    uint256 stakerBalanceAfter = govToken.balanceOf(address(this));
    uint256 contractBalanceAfter = govToken.balanceOf(address(stakingController));
    uint256 totalStakedAfter = stakingController.totalStaked();

    assertTrue(contractBalanceBefore - contractBalanceAfter == amountToUnstake, "contract balance incorrect after unstaking");
    assertTrue(stakerBalanceAfter - stakerBalanceBefore == amountToUnstake, "staker balance incorrect after unstaking");
    assertTrue(totalStakedBefore - totalStakedAfter == amountToUnstake, "total staked incorrect after unstaking");

    assert(stakingController.accumulatedVotingPowerOf(address(this)) == 0);

    assert(stakingController.stakeOf(address(this)) == amountToStake - amountToUnstake);
  }

  function testNonselfUnstaking(uint256 amountToStake, uint256 amountToUnstake) public {
    vm.assume(amountToStake > amountToUnstake && amountToStake < totalSupply);
    vm.assume(amountToUnstake > 0 && amountToUnstake < totalSupply);

    vm.warp(30 days);

    stakingController.stake(amountToStake);

    // advancing 1 day
    vm.warp(block.timestamp + 1 days);
    assert(veToken.balanceOf(address(this)) == 0);

    stakingController.claimAccumulatedVotingPower();
    assert(veToken.balanceOf(address(this)) == amountToStake * 1000 / 297625);

    uint256 stakerBalanceBefore = govToken.balanceOf(address(this));
    uint256 contractBalanceBefore = govToken.balanceOf(address(stakingController));
    uint256 totalStakedBefore = stakingController.totalStaked();

    uint256 allTheVp = veToken.balanceOf(address(this));
    stakingController.declareUnstake(amountToUnstake);

    // impersonate some other address in order to verify only the owner
    // can unstake in the period between 7 and 10 days from declaring
    vm.startPrank(address(0x1));
    // should fail between days 7 and 10 after declaring
    vm.warp(block.timestamp + 8 days);
    vm.expectRevert(abi.encodeWithSignature("UnstakeTooEarly()"));
    stakingController.unstake(address(this));

    // 11 days passed since declaring, should unstake successfully
    vm.warp(block.timestamp + 3 days);
//    vm.expectEmit(true, true, true, false);
//    emit Transfer(address(this), address(0), allTheVp);
    stakingController.unstake(address(this));

    uint256 stakerBalanceAfter = govToken.balanceOf(address(this));
    uint256 contractBalanceAfter = govToken.balanceOf(address(stakingController));
    uint256 totalStakedAfter = stakingController.totalStaked();

    assertTrue(contractBalanceBefore - contractBalanceAfter == amountToUnstake, "contract balance incorrect after unstaking");
    assertTrue(stakerBalanceAfter - stakerBalanceBefore == amountToUnstake, "staker balance incorrect after unstaking");
    assertTrue(totalStakedBefore - totalStakedAfter == amountToUnstake, "total staked incorrect after unstaking");

    assert(stakingController.accumulatedVotingPowerOf(address(this)) == 0);
    assert(stakingController.stakeOf(address(this)) == amountToStake - amountToUnstake);
  }

  function testUnstakingDeclaredFailure(uint256 amountToStake) public {
    vm.assume(amountToStake > 1 && amountToStake < totalSupply);
    uint256 amountToUnstake = amountToStake / 2;

    vm.warp(30 days);

    stakingController.stake(amountToStake);

    // advancing 1 day
    vm.warp(block.timestamp + 1 days);
    assertTrue(veToken.balanceOf(address(this)) == 0, "initial vp must be zero");

    stakingController.claimAccumulatedVotingPower();

    uint256 stakerBalanceBefore = govToken.balanceOf(address(this));
    uint256 contractBalanceBefore = govToken.balanceOf(address(stakingController));
    uint256 totalStakedBefore = stakingController.totalStaked();

    stakingController.declareUnstake(amountToUnstake);

    vm.warp(block.timestamp + 3 days);

    address thisAddress = address(this);
    // expect failure
    vm.expectRevert(abi.encodeWithSignature("UnstakeTooEarly()"));
    stakingController.unstake(thisAddress);
  }

  function testUnstakeNotDeclared(uint256 amountToStake) public {
    vm.assume(amountToStake > 1 && amountToStake < totalSupply);
    uint256 amountToUnstake = amountToStake / 2;

    vm.warp(30 days);

    stakingController.stake(amountToStake);

    vm.expectRevert(abi.encodeWithSignature("UnstakeNotDeclared()"));
    stakingController.unstake(address(this));
  }

  function testStakeNotEnough(uint256 amountToStake) public {
    vm.assume(amountToStake > 1 && amountToStake < totalSupply);
    uint256 amountToUnstake = amountToStake * 2;

    vm.warp(30 days);

    stakingController.stake(amountToStake);

    vm.warp(block.timestamp + 1 days);

    stakingController.declareUnstake(amountToUnstake);

    vm.warp(block.timestamp + 8 days);

    vm.expectRevert(abi.encodeWithSignature("StakeNotEnough()"));
    stakingController.unstake(address(this));
  }

  function testUnstakeTooEarly(uint256 amountToStake) public {
    vm.assume(amountToStake > 1 && amountToStake < totalSupply);
    uint256 amountToUnstake = amountToStake / 2;

    vm.warp(30 days);

    stakingController.stake(amountToStake);

    // advancing 1 day
    vm.warp(block.timestamp + 1 days);
    assertTrue(veToken.balanceOf(address(this)) == 0, "initial vp must be zero");

    stakingController.claimAccumulatedVotingPower();

    uint256 stakerBalanceBefore = govToken.balanceOf(address(this));
    uint256 contractBalanceBefore = govToken.balanceOf(address(stakingController));
    uint256 totalStakedBefore = stakingController.totalStaked();

    stakingController.declareUnstake(amountToUnstake);

    vm.warp(block.timestamp + 3 days);

    vm.expectRevert(abi.encodeWithSignature("UnstakeTooEarly()"));
    stakingController.unstake(address(this));
  }

  function testUnstakeAlreadyDeclared(uint256 amountToStake) public {
    vm.assume(amountToStake > 1 && amountToStake < totalSupply);
    uint256 amountToUnstake = amountToStake / 2;

    vm.warp(30 days);

    stakingController.stake(amountToStake);

    // advancing 1 day
    vm.warp(block.timestamp + 1 days);
    assertTrue(veToken.balanceOf(address(this)) == 0, "initial vp must be zero");

    stakingController.claimAccumulatedVotingPower();

    uint256 stakerBalanceBefore = govToken.balanceOf(address(this));
    uint256 contractBalanceBefore = govToken.balanceOf(address(stakingController));
    uint256 totalStakedBefore = stakingController.totalStaked();

    stakingController.declareUnstake(amountToUnstake);

    vm.warp(block.timestamp + 3 days);

    vm.expectRevert(abi.encodeWithSignature("UnstakeAlreadyDeclared()"));
    stakingController.declareUnstake(amountToUnstake);
  }

  function testUnstakeAmountZero(uint256 amountToStake) public {
    vm.assume(amountToStake > 1 && amountToStake < totalSupply);
    uint256 amountToUnstake = amountToStake / 2;

    vm.warp(30 days);

    stakingController.stake(amountToStake);

    // advancing 1 day
    vm.warp(block.timestamp + 1 days);
    assertTrue(veToken.balanceOf(address(this)) == 0, "initial vp must be zero");

    stakingController.claimAccumulatedVotingPower();

    uint256 stakerBalanceBefore = govToken.balanceOf(address(this));
    uint256 contractBalanceBefore = govToken.balanceOf(address(stakingController));
    uint256 totalStakedBefore = stakingController.totalStaked();

    vm.expectRevert(abi.encodeWithSignature("UnstakeAmountZero()"));
    stakingController.declareUnstake(0);

    // not possible because of earlier UnstakeNotDeclared thrown
//    vm.warp(block.timestamp + 3 days);
//
//    vm.expectRevert(abi.encodeWithSignature("UnstakeAmountZero()"));
//    stakingController.unstake(address(this));
  }
}
