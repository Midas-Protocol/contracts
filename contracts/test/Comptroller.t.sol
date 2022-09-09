// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MidasFlywheel } from "../../midas/strategies/flywheel/MidasFlywheel.sol";
import { Comptroller } from "../../compound/Comptroller.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";

contract ComptrollerTest is BaseTest {
  Comptroller internal comptroller;
  MidasFlywheel internal flywheel;
  address internal nonOwner = address(0x2222);

  event Failure(uint256 error, uint256 info, uint256 detail);

  function setUp() external {
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

  function test__replaceFlywheel() external {
    comptroller._addRewardsDistributor(address(flywheel));

    address newFlywheel = createNewFlywheel();
    comptroller.replaceFlywheel(address(flywheel), newFlywheel);

    assertEq(comptroller.rewardsDistributors(0), newFlywheel);
  }

  function test__replaceFlywheelRevertsIfNonOwner() external {
    comptroller._addRewardsDistributor(address(flywheel));

    address newFlywheel = createNewFlywheel();

    vm.startPrank(nonOwner);
    vm.expectRevert("should have admin rights");
    comptroller.replaceFlywheel(address(flywheel), newFlywheel);

    assertEq(comptroller.rewardsDistributors(0), address(flywheel));
  }

  function test__replaceFlywheelRevertsIfNewFlywheelIsAddressZero() external {
    comptroller._addRewardsDistributor(address(flywheel));

    vm.expectRevert("zero address for new flywheel");
    comptroller.replaceFlywheel(address(flywheel), address(0));

    assertEq(comptroller.rewardsDistributors(0), address(flywheel));
  }

  function test__replaceFlywheelRevertsIfNewFLywheelIsTheSameAddress() external {
    comptroller._addRewardsDistributor(address(flywheel));

    vm.expectRevert("same flywheel");
    comptroller.replaceFlywheel(address(flywheel), address(flywheel));

    assertEq(comptroller.rewardsDistributors(0), address(flywheel));
  }
}
