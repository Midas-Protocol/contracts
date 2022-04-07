// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import { EllipsisERC4626, ILpTokenStaker } from "../compound/strategies/EllipsisERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockLpTokenStaker, IERC20Mintable } from "./mocks/ellipsis/MockLpTokenStaker.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { Authority } from "solmate/auth/Auth.sol";

contract EllipsisERC4626Test is DSTest {
  using stdStorage for StdStorage;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  StdStorage stdstore;

  EllipsisERC4626 ellipsisERC4626;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;

  MockERC20 testToken;
  MockERC20 epsToken;
  MockLpTokenStaker mockLpTokenStaker;

  uint256 depositAmount = 100e18;
  ERC20 marketKey;
  address tester = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

  function setUp() public {
    testToken = new MockERC20("TestLpToken", "LP-TST", 18);
    epsToken = new MockERC20("epsToken", "EPX", 18);
    mockLpTokenStaker = new MockLpTokenStaker(IERC20Mintable(address(epsToken)), 1000000e18);

    vm.warp(1);
    mockLpTokenStaker.addPool(address(testToken));
    //mockLpTokenStaker.setMinter(address(mockEpsStaker));

    flywheel = new FlywheelCore(
      epsToken,
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewards(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    ellipsisERC4626 = new EllipsisERC4626(
      testToken,
      "TestVault",
      "TSTV",
      ILpTokenStaker(address(mockLpTokenStaker)),
      FlywheelCore(address(flywheel))
    );
    marketKey = ERC20(address(ellipsisERC4626));
    flywheel.addStrategyForRewards(marketKey);
    flywheel.accrue(marketKey, address(this));
  }

  function testInitializedValues() public {
    assertEq(ellipsisERC4626.name(), "TestVault");
    assertEq(ellipsisERC4626.symbol(), "TSTV");
    assertEq(address(ellipsisERC4626.asset()), address(testToken));
    assertEq(address(ellipsisERC4626.lpTokenStaker()), address(mockLpTokenStaker));
    assertEq(address(marketKey), address(ellipsisERC4626));
    assertEq(testToken.allowance(address(ellipsisERC4626), address(mockLpTokenStaker)), type(uint256).max);
    assertEq(epsToken.allowance(address(ellipsisERC4626), address(flywheelRewards)), type(uint256).max);
  }

  function deposit() public {
    testToken.mint(address(this), depositAmount);
    testToken.approve(address(ellipsisERC4626), depositAmount);
    ellipsisERC4626.deposit(depositAmount, address(this));
  }

  function testDeposit() public {
    deposit();
    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), 0);
    assertEq(testToken.balanceOf(address(mockLpTokenStaker)), depositAmount);

    // //Test that the balance view calls work
    assertEq(ellipsisERC4626.totalAssets(), depositAmount);
    assertEq(ellipsisERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(ellipsisERC4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public {
    deposit();
    ellipsisERC4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), depositAmount);
    assertEq(testToken.balanceOf(address(mockLpTokenStaker)), 0);

    // //Test that we burned the correct amount of token
    assertEq(ellipsisERC4626.balanceOf(address(this)), 0);
  }

  function testAccumulatingEPSRewardsOnDeposit() public {
    vm.warp(2);
    deposit();
    assertEq(epsToken.balanceOf(address(ellipsisERC4626)), 0);
    assertEq(epsToken.balanceOf(address(flywheel)), 0);
    assertEq(epsToken.balanceOf(address(flywheelRewards)), 0);

    vm.warp(3);
    deposit();
    flywheel.accrue(ERC20(ellipsisERC4626), address(this));
    assertEq(epsToken.balanceOf(address(ellipsisERC4626)), 0);
    assertEq(epsToken.balanceOf(address(flywheel)), 0);
    assertEq(epsToken.balanceOf(address(flywheelRewards)), 0.5e18);
  }

  function testAccumulatingEPSRewardsOnWithdrawal() public {
    vm.warp(2);
    deposit();

    vm.warp(3);
    ellipsisERC4626.withdraw(1, address(this), address(this));
    vm.warp(4);
    flywheel.accrue(ERC20(ellipsisERC4626), address(this));
    assertEq(epsToken.balanceOf(address(ellipsisERC4626)), 0);
    assertEq(epsToken.balanceOf(address(flywheel)), 0);
    assertEq(epsToken.balanceOf(address(flywheelRewards)), 0.5e18);
  }

  function testClaimRewards() public {
    vm.warp(2);
    deposit();
    vm.warp(3);
    ellipsisERC4626.withdraw(1, address(this), address(this));
    flywheel.accrue(ERC20(ellipsisERC4626), address(this));
    flywheel.claimRewards(address(this));
    assertEq(epsToken.balanceOf(address(this)), 499999999999999999);
  }

  function testClaimForMultipleUser() public {
    vm.warp(2);
    deposit();
    vm.startPrank(tester);
    testToken.mint(tester, depositAmount);
    testToken.approve(address(ellipsisERC4626), depositAmount);
    ellipsisERC4626.deposit(depositAmount, tester);
    vm.stopPrank();

    vm.warp(3);
    ellipsisERC4626.withdraw(1, address(this), address(this));
    flywheel.accrue(ERC20(ellipsisERC4626), address(this), tester);
    flywheel.claimRewards(address(this));
    flywheel.claimRewards(tester);
    assertEq(epsToken.balanceOf(address(tester)), 0.5e18);
    assertEq(epsToken.balanceOf(address(this)), 499999999999999999);
  }
}
