// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
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
  struct RewardsCycle {
    uint32 start;
    uint32 end;
    uint192 reward;
  }

  Vm public constant vm = Vm(HEVM_ADDRESS);

  EllipsisERC4626 ellipsisERC4626;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;

  MockERC20 testToken;
  MockERC20 epsToken;
  MockLpTokenStaker mockLpTokenStaker;

  uint256 depositAmount = 100e18;
  uint192 rewardsStream = 0.5e18;
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
      FlywheelCore(address(flywheel)),
      ILpTokenStaker(address(mockLpTokenStaker))
    );
    marketKey = ERC20(address(ellipsisERC4626));
    flywheel.addStrategyForRewards(marketKey);
    vm.warp(2);
  }

  function testInitializedValues() public {
    assertEq(ellipsisERC4626.name(), "Midas TestLpToken Vault");
    assertEq(ellipsisERC4626.symbol(), "mvLP-TST");
    assertEq(address(ellipsisERC4626.asset()), address(testToken));
    assertEq(address(ellipsisERC4626.lpTokenStaker()), address(mockLpTokenStaker));
    assertEq(address(marketKey), address(ellipsisERC4626));
    assertEq(testToken.allowance(address(ellipsisERC4626), address(mockLpTokenStaker)), type(uint256).max);
    assertEq(epsToken.allowance(address(ellipsisERC4626), address(flywheelRewards)), type(uint256).max);
  }

  function deposit() public {
    testToken.mint(address(this), depositAmount);
    testToken.approve(address(ellipsisERC4626), depositAmount);
    // flywheelPreSupplierAction -- usually this would be done in Comptroller when supplying
    flywheel.accrue(ERC20(ellipsisERC4626), address(this));
    ellipsisERC4626.deposit(depositAmount, address(this));
    // flywheelPreSupplierAction
    flywheel.accrue(ERC20(ellipsisERC4626), address(this));
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
    deposit();
    assertEq(epsToken.totalSupply(), 0);
    vm.warp(3);

    deposit();

    assertEq(epsToken.totalSupply(), rewardsStream);

    assertEq(epsToken.balanceOf(address(ellipsisERC4626)), rewardsStream);
  }

  function testAccumulatingEPSRewardsOnWithdrawal() public {
    deposit();
    assertEq(epsToken.totalSupply(), 0);
    vm.warp(3);

    ellipsisERC4626.withdraw(1, address(this), address(this));

    assertEq(epsToken.totalSupply(), rewardsStream);

    assertEq(epsToken.balanceOf(address(ellipsisERC4626)), rewardsStream);
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    deposit();

    // No EPS-token have yet been minted as rewards
    assertEq(epsToken.totalSupply(), 0);

    (uint32 start, uint32 end, uint192 reward) = flywheelRewards.rewardsCycle(ERC20(address(ellipsisERC4626)));

    // Rewards can be transfered in the next cycle at time block.timestamp == 3
    assertEq(end, 3);

    // Reward amount is still 0
    assertEq(reward, 0);
    vm.warp(3);

    // Call withdraw (could also be deposit() on the erc4626 or claim() on the epsStaker directly) to claim rewards
    ellipsisERC4626.withdraw(1, address(this), address(this));

    // EPS-token have been minted
    assertEq(epsToken.totalSupply(), rewardsStream);

    // The ERC-4626 holds all rewarded eps-token now
    assertEq(epsToken.balanceOf(address(ellipsisERC4626)), rewardsStream);

    // Accrue rewards to send rewards to flywheelRewards
    flywheel.accrue(ERC20(ellipsisERC4626), address(this));
    assertEq(epsToken.balanceOf(address(flywheelRewards)), rewardsStream);

    (start, end, reward) = flywheelRewards.rewardsCycle(ERC20(address(ellipsisERC4626)));

    // Rewards can be transfered in the next cycle at time block.timestamp == 4
    assertEq(end, 4);

    // Reward amount is expected value
    assertEq(reward, rewardsStream);
    vm.warp(4);

    // Finally accrue reward from last cycle
    flywheel.accrue(ERC20(ellipsisERC4626), address(this));

    // Claim Rewards for the user
    flywheel.claimRewards(address(this));

    // NOTE: Not sure why it doesnt transfer the full amount
    assertEq(epsToken.balanceOf(address(this)), rewardsStream - 1);
    assertEq(epsToken.balanceOf(address(flywheel)), 0);
  }

  function testClaimForMultipleUser() public {
    deposit();
    vm.startPrank(tester);
    testToken.mint(tester, depositAmount);
    testToken.approve(address(ellipsisERC4626), depositAmount);
    ellipsisERC4626.deposit(depositAmount, tester);
    vm.stopPrank();

    assertEq(epsToken.totalSupply(), 0);

    (uint32 start, uint32 end, uint192 reward) = flywheelRewards.rewardsCycle(ERC20(address(ellipsisERC4626)));

    assertEq(end, 3);

    assertEq(reward, 0);
    vm.warp(3);

    ellipsisERC4626.withdraw(1, address(this), address(this));

    assertEq(epsToken.totalSupply(), rewardsStream);

    assertEq(epsToken.balanceOf(address(ellipsisERC4626)), rewardsStream);

    flywheel.accrue(ERC20(ellipsisERC4626), address(this));
    assertEq(epsToken.balanceOf(address(flywheelRewards)), rewardsStream);

    (start, end, reward) = flywheelRewards.rewardsCycle(ERC20(address(ellipsisERC4626)));

    assertEq(end, 4);

    assertEq(reward, rewardsStream);
    vm.warp(4);

    flywheel.accrue(ERC20(ellipsisERC4626), address(this), tester);

    flywheel.claimRewards(address(this));
    flywheel.claimRewards(tester);

    assertEq(epsToken.balanceOf(address(tester)), rewardsStream / 2);
    assertEq(epsToken.balanceOf(address(this)), (rewardsStream / 2) - 1);
    assertEq(epsToken.balanceOf(address(flywheel)), 0);
  }
}
