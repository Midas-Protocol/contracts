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
  address internal owner = address(0x7777);

  event Failure(uint256 error, uint256 info, uint256 detail);

  function _setUp() internal {
    try new Comptroller(payable(address(this))) returns (Comptroller _comp) {
      comptroller = _comp;
    } catch {
      revert("at comp");
    }

    try new MidasFlywheel() returns (MidasFlywheel _fw) {
      flywheel = _fw;
    } catch {
      revert("at fw");
    }

    //    vm.prank(owner);
    //    try
    //      flywheel.initialize(ERC20(address(0)), IFlywheelRewards(address(0)), IFlywheelBooster(address(0)), owner)
    //    {} catch {
    //      revert("at init");
    //    }
    //    comptroller = new Comptroller(payable(address(this)));
    //    flywheel = new MidasFlywheel();
    //    flywheel.initialize(ERC20(address(0)), IFlywheelRewards(address(0)), IFlywheelBooster(address(0)), address(this));
  }

  function test__setFlywheel() public {
    _setUp();
    flywheel.initialize(ERC20(address(0)), IFlywheelRewards(address(0)), IFlywheelBooster(address(0)), owner);
    comptroller._addRewardsDistributor(address(flywheel));

    assertEq(comptroller.rewardsDistributors(0), address(flywheel));
  }

  function test__setFlywheelRevertsIfNonOwner() public {
    _setUp();
    flywheel.initialize(ERC20(address(0)), IFlywheelRewards(address(0)), IFlywheelBooster(address(0)), owner);
    vm.startPrank(nonOwner);
    vm.expectEmit(false, false, false, true, address(comptroller));
    emit Failure(1, 2, 0);
    comptroller._addRewardsDistributor(address(flywheel));
  }
}
