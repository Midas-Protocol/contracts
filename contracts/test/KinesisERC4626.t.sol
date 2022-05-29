// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { KinesisERC4626, IMiniChefV2 } from "../compound/strategies/KinesisERC4626.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { MockMiniChefV2 } from "./mocks/kinesis/MockMiniChefV2.sol";
import { SimpleRewarder, IRewarder } from "./mocks/kinesis/SimpleRewarder.sol";
import { IStrategy } from "./mocks/autofarm/IStrategy.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

contract KinesisERC4626Test is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  KinesisERC4626 kinesisERC4626;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;

  MockERC20 lpToken;
  MockERC20 rewardToken;
  MockMiniChefV2 mockMiniChef;
  SimpleRewarder simpleRewarder;

  uint256 depositAmount = 100e18;
  uint256 rewardsStream = 1e18;
  ERC20 marketKey;
  address tester = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  uint256 startTs = block.timestamp;

  function setUp() public {
    lpToken = new MockERC20("TestToken", "TST", 18);
    rewardToken = new MockERC20("KinesisToken", "KINESIS", 18);
    mockMiniChef = new MockMiniChefV2(IERC20(address(rewardToken)));
    simpleRewarder = new SimpleRewarder(address(mockMiniChef));
    vm.warp(1);
    vm.roll(1);

    mockMiniChef.setSaddlePerSecond(rewardsStream);
    mockMiniChef.add(1, IERC20(address(lpToken)), IRewarder(address(simpleRewarder)));
    rewardToken.mint(address(mockMiniChef), 100000e18);
    rewardToken.mint(address(simpleRewarder), 100000e18);
    simpleRewarder.init(
      abi.encode(IERC20(address(rewardToken)), address(this), uint256(2e18), IERC20(address(lpToken)), uint256(0))
    );

    flywheel = new FlywheelCore(
      rewardToken,
      FlywheelDynamicRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewards(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    kinesisERC4626 = new KinesisERC4626(
      lpToken,
      FlywheelCore(address(flywheel)),
      0,
      IMiniChefV2(address(mockMiniChef))
    );
    marketKey = ERC20(address(kinesisERC4626));
    flywheel.addStrategyForRewards(marketKey);

    vm.warp(2);
    vm.roll(2);
  }

  function testInitializedValues() public {
    assertEq(kinesisERC4626.name(), "Midas TestToken Vault");
    assertEq(kinesisERC4626.symbol(), "mvTST");
    assertEq(address(kinesisERC4626.asset()), address(lpToken));
    assertEq(address(kinesisERC4626.miniChef()), address(mockMiniChef));
    assertEq(address(marketKey), address(kinesisERC4626));
    assertEq(lpToken.allowance(address(kinesisERC4626), address(mockMiniChef)), type(uint256).max);
    assertEq(rewardToken.allowance(address(kinesisERC4626), address(flywheelRewards)), type(uint256).max);
  }

  function deposit() public {
    lpToken.mint(address(this), depositAmount);
    lpToken.approve(address(kinesisERC4626), depositAmount);
    // flywheelPreSupplierAction -- usually this would be done in Comptroller when supplying
    flywheel.accrue(ERC20(kinesisERC4626), address(this));
    kinesisERC4626.deposit(depositAmount, address(this));
    // flywheelPreSupplierAction
    flywheel.accrue(ERC20(kinesisERC4626), address(this));
  }

  function testDeposit() public {
    deposit();
    //Test that the actual transfers worked
    assertEq(lpToken.balanceOf(address(this)), 0);
    assertEq(lpToken.balanceOf(address(mockMiniChef)), depositAmount);

    // //Test that the balance view calls work
    assertEq(kinesisERC4626.totalAssets(), depositAmount);
    assertEq(kinesisERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(kinesisERC4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public {
    deposit();
    kinesisERC4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(lpToken.balanceOf(address(this)), depositAmount);
    assertEq(lpToken.balanceOf(address(mockMiniChef)), 0);

    // //Test that we burned the correct amount of token
    assertEq(kinesisERC4626.balanceOf(address(this)), 0);
  }

  function testAccumulatingRewardsOnDeposit() public {
    deposit();

    vm.warp(3);
    vm.roll(3);

    deposit();
    assertEq(rewardToken.balanceOf(address(kinesisERC4626)), rewardsStream * 2);
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    deposit();
    vm.warp(3);
    vm.roll(3);

    kinesisERC4626.withdraw(1, address(this), address(this));

    assertEq(rewardToken.balanceOf(address(kinesisERC4626)), rewardsStream * 3);
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    deposit();
    vm.warp(3);
    vm.roll(3);

    kinesisERC4626.withdraw(1, address(this), address(this));
    // flywheelPreSupplierAction
    flywheel.accrue(ERC20(kinesisERC4626), address(this));
    vm.warp(4);
    vm.roll(4);

    flywheel.accrue(ERC20(kinesisERC4626), address(this));
    flywheel.claimRewards(address(this));
    assertEq(rewardToken.balanceOf(address(this)), (rewardsStream * 3) - 1);
  }

  function testClaimForMultipleUser() public {
    deposit();
    vm.startPrank(tester);
    lpToken.mint(tester, depositAmount);
    lpToken.approve(address(kinesisERC4626), depositAmount);
    kinesisERC4626.deposit(depositAmount, tester);
    vm.stopPrank();
    vm.warp(3);
    vm.roll(3);

    kinesisERC4626.withdraw(1, address(this), address(this));
    flywheel.accrue(ERC20(kinesisERC4626), address(this));
    vm.warp(4);
    vm.roll(4);

    flywheel.accrue(ERC20(kinesisERC4626), address(this), tester);
    flywheel.claimRewards(address(this));
    flywheel.claimRewards(tester);

    assertEq(rewardToken.balanceOf(address(this)), (rewardsStream * 3) / 2 - 1);
    assertEq(rewardToken.balanceOf(address(this)), (rewardsStream * 3) / 2 - 1);
    assertEq(rewardToken.balanceOf(address(flywheel)), 0);
  }
}
