// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";

contract ComptrollerTest is BaseTest {
  Comptroller internal comptroller;
  MidasFlywheel internal flywheel;
  address internal nonOwner = address(0x2222);

  event Failure(uint256 error, uint256 info, uint256 detail);

  function setUp() public {
    comptroller = new Comptroller(payable(address(this)));
    flywheel = new MidasFlywheel();
    flywheel.initialize(ERC20(address(0)), IFlywheelRewards(address(0)), IFlywheelBooster(address(0)), address(this));
  }

  function createNewFlywheel() public returns (address) {
    MidasFlywheel newFlywheel = new MidasFlywheel();
    newFlywheel.initialize(
      ERC20(address(0)),
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this)
    );
    return address(newFlywheel);
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
