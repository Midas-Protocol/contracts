// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { Comptroller } from "../compound/Comptroller.sol";

import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract ComptrollerTest is BaseTest {
  Comptroller internal comptroller;
  MidasFlywheel internal flywheel;
  address internal nonOwner = address(0x2222);

  event Failure(uint256 error, uint256 info, uint256 detail);

  function setUp() public {
    ERC20 rewardToken = new MockERC20("RewardToken", "RT", 18);
    flywheel = new MidasFlywheel();
    comptroller = new Comptroller(payable(address(this)));
    flywheel.initialize(rewardToken, IFlywheelRewards(address(2)), IFlywheelBooster(address(3)), address(this));
  }

  function test__setFlywheel() external {
    comptroller._addRewardsDistributor(address(flywheel));

    assertEq(comptroller.rewardsDistributors(0), address(flywheel));
  }

  function test__setFlywheelRevertsIfNonOwner() external {
    vm.startPrank(nonOwner);
    vm.expectEmit(false, false, false, true, address(comptroller));
    emit Failure(1, 2, 0);
    comptroller._addRewardsDistributor(address(flywheel));
  }
}
