// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { Authority } from "solmate/auth/Auth.sol";

import { AutofarmERC4626, IAutofarmV2 } from "../compound/strategies/AutofarmERC4626.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { MockStrategy } from "./mocks/autofarm/MockStrategy.sol";
import { MockAutofarmV2 } from "./mocks/autofarm/MockAutofarmV2.sol";
import { IStrategy } from "./mocks/autofarm/IStrategy.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

contract AutofarmERC4626Test is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  AutofarmERC4626 autofarmERC4626;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;

  MockERC20 testToken;
  MockERC20 autoToken;
  MockStrategy mockStrategy;
  MockAutofarmV2 mockAutofarm;

  uint256 depositAmount = 100e18;
  uint256 rewardsStream = 8e15;
  ERC20 marketKey;
  address tester = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  uint256 startTs = block.timestamp;

  function setUp() public {
    testToken = new MockERC20("TestToken", "TST", 18);
    autoToken = new MockERC20("autoToken", "AUTO", 18);
    mockAutofarm = new MockAutofarmV2(address(autoToken));
    mockStrategy = new MockStrategy(address(testToken), address(mockAutofarm));
    vm.warp(1);
    vm.roll(1);

    flywheel = new FlywheelCore(
      autoToken,
      FlywheelDynamicRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewards(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    autofarmERC4626 = new AutofarmERC4626(
      testToken,
      "TestVault",
      "TSTV",
      0,
      autoToken,
      IAutofarmV2(address(mockAutofarm)),
      FlywheelCore(address(flywheel))
    );
    marketKey = ERC20(address(autofarmERC4626));
    flywheel.addStrategyForRewards(marketKey);

    // Add mockStrategy to Autofarm
    mockAutofarm.add(ERC20(address(testToken)), 1, address(mockStrategy));
    vm.warp(2);
    vm.roll(2);
  }

  function testInitializedValues() public {
    assertEq(autofarmERC4626.name(), "TestVault");
    assertEq(autofarmERC4626.symbol(), "TSTV");
    assertEq(address(autofarmERC4626.asset()), address(testToken));
    assertEq(address(autofarmERC4626.autofarm()), address(mockAutofarm));
    assertEq(address(marketKey), address(autofarmERC4626));
    assertEq(testToken.allowance(address(autofarmERC4626), address(mockAutofarm)), type(uint256).max);
    assertEq(autoToken.allowance(address(autofarmERC4626), address(flywheelRewards)), type(uint256).max);
  }

  function deposit() public {
    testToken.mint(address(this), depositAmount);
    testToken.approve(address(autofarmERC4626), depositAmount);
    // flywheelPreSupplierAction -- usually this would be done in Comptroller when supplying
    flywheel.accrue(ERC20(autofarmERC4626), address(this));
    autofarmERC4626.deposit(depositAmount, address(this));
    // flywheelPreSupplierAction
    flywheel.accrue(ERC20(autofarmERC4626), address(this));
  }

  function testDeposit() public {
    deposit();
    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), 0);
    assertEq(testToken.balanceOf(address(mockAutofarm)), 0);
    assertEq(testToken.balanceOf(address(mockStrategy)), depositAmount);

    // //Test that the balance view calls work
    assertEq(autofarmERC4626.totalAssets(), depositAmount);
    assertEq(autofarmERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(autofarmERC4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public {
    deposit();
    autofarmERC4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), depositAmount);
    assertEq(testToken.balanceOf(address(mockAutofarm)), 0);
    assertEq(testToken.balanceOf(address(mockStrategy)), 0);

    // //Test that we burned the correct amount of token
    assertEq(autofarmERC4626.balanceOf(address(this)), 0);
  }

  function testAccumulatingAutoRewardsOnDeposit() public {
    deposit();

    vm.warp(3);
    vm.roll(3);

    deposit();
    assertEq(autoToken.balanceOf(address(autofarmERC4626)), rewardsStream);
  }

  function testAccumulatingAutoRewardsOnWithdrawal() public {
    deposit();
    vm.warp(3);
    vm.roll(3);

    autofarmERC4626.withdraw(1, address(this), address(this));

    assertEq(autoToken.balanceOf(address(autofarmERC4626)), rewardsStream);
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    deposit();
    vm.warp(3);
    vm.roll(3);

    autofarmERC4626.withdraw(1, address(this), address(this));
    // flywheelPreSupplierAction
    flywheel.accrue(ERC20(autofarmERC4626), address(this));
    vm.warp(4);
    vm.roll(4);

    flywheel.accrue(ERC20(autofarmERC4626), address(this));
    flywheel.claimRewards(address(this));
    assertEq(autoToken.balanceOf(address(this)), rewardsStream - 1);
  }

  function testClaimForMultipleUser() public {
    deposit();
    vm.startPrank(tester);
    testToken.mint(tester, depositAmount);
    testToken.approve(address(autofarmERC4626), depositAmount);
    autofarmERC4626.deposit(depositAmount, tester);
    vm.stopPrank();
    vm.warp(3);
    vm.roll(3);

    autofarmERC4626.withdraw(1, address(this), address(this));
    flywheel.accrue(ERC20(autofarmERC4626), address(this));
    vm.warp(4);
    vm.roll(4);

    flywheel.accrue(ERC20(autofarmERC4626), address(this), tester);
    flywheel.claimRewards(address(this));
    flywheel.claimRewards(tester);

    assertEq(autoToken.balanceOf(address(this)), (rewardsStream / 2) - 1);
    assertEq(autoToken.balanceOf(address(this)), (rewardsStream / 2) - 1);
    assertEq(autoToken.balanceOf(address(flywheel)), 0);
  }
}
