// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { DotDotLpERC4626, ILpDepositor } from "../compound/strategies/DotDotLpERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockLpDepositor } from "./mocks/dotdot/MockLpDepositor.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { Authority } from "solmate/auth/Auth.sol";

contract DotDotLpERC4626Test is DSTest {
  struct RewardsCycle {
    uint32 start;
    uint32 end;
    uint192 reward;
  }

  Vm public constant vm = Vm(HEVM_ADDRESS);

  DotDotLpERC4626 dotDotERC4626;

  MockERC20 lpToken;

  MockERC20 dddToken;
  FlywheelCore dddFlywheel;
  FuseFlywheelDynamicRewards dddRewards;

  MockERC20 epxToken;
  FlywheelCore epxFlywheel;
  FuseFlywheelDynamicRewards epxRewards;

  MockLpDepositor mockLpDepositor;

  uint256 depositAmount = 100e18;
  uint192 expectedReward = 1e18;
  ERC20 marketKey;
  address tester = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

  function setUp() public {
    vm.warp(1);
    dddToken = new MockERC20("dddToken", "DDD", 18);
    dddFlywheel = new FlywheelCore(
      dddToken,
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );
    dddRewards = new FuseFlywheelDynamicRewards(dddFlywheel, 1);
    dddFlywheel.setFlywheelRewards(dddRewards);

    epxToken = new MockERC20("epxToken", "EPX", 18);
    epxFlywheel = new FlywheelCore(
      epxToken,
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );
    epxRewards = new FuseFlywheelDynamicRewards(epxFlywheel, 1);
    epxFlywheel.setFlywheelRewards(epxRewards);

    lpToken = new MockERC20("TestLpToken", "LP-TST", 18);
    mockLpDepositor = new MockLpDepositor(epxToken, dddToken, lpToken);

    dotDotERC4626 = new DotDotLpERC4626(
      lpToken,
      FlywheelCore(address(dddFlywheel)),
      FlywheelCore(address(epxFlywheel)),
      ILpDepositor(address(mockLpDepositor))
    );
    marketKey = ERC20(address(dotDotERC4626));
    dddFlywheel.addStrategyForRewards(marketKey);
    epxFlywheel.addStrategyForRewards(marketKey);
    vm.warp(2);
  }

  function testInitializedValues() public {
    assertEq(dotDotERC4626.name(), "Midas TestLpToken Vault");
    assertEq(dotDotERC4626.symbol(), "mvLP-TST");
    assertEq(address(dotDotERC4626.asset()), address(lpToken));
    assertEq(address(dotDotERC4626.lpDepositor()), address(mockLpDepositor));
    assertEq(address(marketKey), address(dotDotERC4626));
    assertEq(lpToken.allowance(address(dotDotERC4626), address(mockLpDepositor)), type(uint256).max);
    assertEq(dddToken.allowance(address(dotDotERC4626), address(dddRewards)), type(uint256).max);
    assertEq(epxToken.allowance(address(dotDotERC4626), address(epxRewards)), type(uint256).max);
  }

  function deposit() public {
    lpToken.mint(address(this), depositAmount);
    lpToken.approve(address(dotDotERC4626), depositAmount);
    // flywheelPreSupplierAction -- usually this would be done in Comptroller when supplying
    dddFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    epxFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    dotDotERC4626.deposit(depositAmount, address(this));
    // flywheelPreSupplierAction
    dddFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    epxFlywheel.accrue(ERC20(dotDotERC4626), address(this));
  }

  function testDeposit() public {
    deposit();
    //Test that the actual transfers worked
    assertEq(lpToken.balanceOf(address(this)), 0);
    assertEq(lpToken.balanceOf(address(mockLpDepositor)), depositAmount);

    // //Test that the balance view calls work
    assertEq(dotDotERC4626.totalAssets(), depositAmount);
    assertEq(dotDotERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public {
    deposit();
    dotDotERC4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(lpToken.balanceOf(address(this)), depositAmount);
    assertEq(lpToken.balanceOf(address(mockLpDepositor)), 0);

    // //Test that we burned the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(this)), 0);
  }

  function testAccumulatingEPSRewardsOnDeposit() public {
    deposit();
    assertEq(dddToken.totalSupply(), expectedReward);
    assertEq(epxToken.totalSupply(), expectedReward);

    assertEq(dddToken.balanceOf(address(dotDotERC4626)), expectedReward);
    assertEq(epxToken.balanceOf(address(dotDotERC4626)), expectedReward);
  }

  function testAccumulatingEPSRewardsOnWithdrawal() public {
    deposit();
    assertEq(dddToken.totalSupply(), expectedReward);
    assertEq(epxToken.totalSupply(), expectedReward);

    dotDotERC4626.withdraw(1, address(this), address(this));

    assertEq(dddToken.totalSupply(), expectedReward * 2);
    assertEq(epxToken.totalSupply(), expectedReward * 2);

    assertEq(dddToken.balanceOf(address(dotDotERC4626)), expectedReward * 2);
    assertEq(epxToken.balanceOf(address(dotDotERC4626)), expectedReward * 2);
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    deposit();

    // No EPS-token have yet been minted as rewards
    assertEq(dddToken.totalSupply(), expectedReward);
    assertEq(epxToken.totalSupply(), expectedReward);

    (uint32 dddStart, uint32 dddEnd, uint192 dddReward) = dddRewards.rewardsCycle(ERC20(address(dotDotERC4626)));
    (uint32 epxStart, uint32 epxEnd, uint192 epxReward) = dddRewards.rewardsCycle(ERC20(address(dotDotERC4626)));

    // Rewards can be transfered in the next cycle at time block.timestamp == 2
    assertEq(dddEnd, 3);
    assertEq(epxEnd, 3);

    // Reward amount is still 0
    assertEq(dddReward, 0);
    assertEq(epxReward, 0);

    vm.warp(3);

    // Call withdraw (could also be deposit() on the erc4626 or claim() on the epsStaker directly) to claim rewards
    dotDotERC4626.withdraw(1, address(this), address(this));

    // rewardsToken have been minted
    assertEq(dddToken.totalSupply(), expectedReward * 2);
    assertEq(epxToken.totalSupply(), expectedReward * 2);

    // The ERC-4626 holds all rewarded token now
    assertEq(dddToken.balanceOf(address(dotDotERC4626)), expectedReward * 2);
    assertEq(epxToken.balanceOf(address(dotDotERC4626)), expectedReward * 2);

    // Accrue rewards to send rewards to flywheelRewards
    dddFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    epxFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    assertEq(dddToken.balanceOf(address(dddRewards)), expectedReward * 2);
    assertEq(epxToken.balanceOf(address(epxRewards)), expectedReward * 2);

    (dddStart, dddEnd, dddReward) = dddRewards.rewardsCycle(ERC20(address(dotDotERC4626)));
    (epxStart, epxEnd, epxReward) = epxRewards.rewardsCycle(ERC20(address(dotDotERC4626)));

    // Rewards can be transfered in the next cycle at time block.timestamp == 3
    assertEq(dddEnd, 4);
    assertEq(epxEnd, 4);

    // Reward amount is expected value
    assertEq(dddReward, expectedReward * 2);
    assertEq(epxReward, expectedReward * 2);

    vm.warp(4);

    // Finally accrue reward from last cycle
    dddFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    epxFlywheel.accrue(ERC20(dotDotERC4626), address(this));

    // Claim Rewards for the user
    dddFlywheel.claimRewards(address(this));
    epxFlywheel.claimRewards(address(this));

    assertEq(dddToken.balanceOf(address(this)), (expectedReward * 2) - 1);
    assertEq(dddToken.balanceOf(address(dddFlywheel)), 0);
    assertEq(epxToken.balanceOf(address(this)), (expectedReward * 2) - 1);
    assertEq(epxToken.balanceOf(address(epxFlywheel)), 0);
  }

  function testClaimForMultipleUser() public {
    // Note: As shown in the previous test epx works in the same way as ddd so im gonna only test ddd in here

    deposit();
    vm.startPrank(tester);
    lpToken.mint(tester, depositAmount);
    lpToken.approve(address(dotDotERC4626), depositAmount);
    dotDotERC4626.deposit(depositAmount, tester);
    vm.stopPrank();

    assertEq(dddToken.totalSupply(), expectedReward * 2);

    (uint32 start, uint32 end, uint192 reward) = dddRewards.rewardsCycle(ERC20(address(dotDotERC4626)));

    assertEq(end, 3);

    assertEq(reward, 0);
    vm.warp(3);

    dotDotERC4626.withdraw(1, address(this), address(this));

    assertEq(dddToken.totalSupply(), expectedReward * 3);

    assertEq(dddToken.balanceOf(address(dotDotERC4626)), expectedReward * 3);

    dddFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    assertEq(dddToken.balanceOf(address(dddRewards)), expectedReward * 3);

    (start, end, reward) = dddRewards.rewardsCycle(ERC20(address(dotDotERC4626)));

    assertEq(end, 4);

    assertEq(reward, expectedReward * 3);
    vm.warp(4);

    dddFlywheel.accrue(ERC20(dotDotERC4626), address(this), tester);

    dddFlywheel.claimRewards(address(this));
    dddFlywheel.claimRewards(tester);

    assertEq(dddToken.balanceOf(address(tester)), (expectedReward * 3) / 2);
    assertEq(dddToken.balanceOf(address(this)), ((expectedReward * 3) / 2) - 1);
    assertEq(dddToken.balanceOf(address(dddFlywheel)), 0);
  }
}
