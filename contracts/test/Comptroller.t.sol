// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";

contract ComptrollerTest is BaseTest {
  Comptroller internal comptroller;
  MidasFlywheel internal fw;
  address internal nonOwner = address(0x2222);

  event Failure(uint256 error, uint256 info, uint256 detail);

  function setUp() public {
    comptroller = new Comptroller(payable(address(this)));
    fw = new MidasFlywheel();
    fw.initialize(ERC20(address(1)), IFlywheelRewards(address(2)), IFlywheelBooster(address(3)), address(this));
  }

  function test__setFlywheel() external {
    comptroller._addRewardsDistributor(address(fw));

    assertEq(comptroller.rewardsDistributors(0), address(fw));
  }

  function test__setFlywheelRevertsIfNonOwner() external {
    vm.startPrank(nonOwner);
    vm.expectEmit(false, false, false, true, address(comptroller));
    emit Failure(1, 2, 0);
    comptroller._addRewardsDistributor(address(fw));
  }
}
