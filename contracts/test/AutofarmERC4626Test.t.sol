// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { Authority } from "solmate/auth/Auth.sol";

import { AutofarmERC4626, IAutofarmV2 } from "../midas/strategies/AutofarmERC4626.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { MockStrategy } from "./mocks/autofarm/MockStrategy.sol";
import { MockAutofarmV2 } from "./mocks/autofarm/MockAutofarmV2.sol";
import { IStrategy } from "./mocks/autofarm/IStrategy.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract AutofarmERC4626Test is BaseTest {
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

  address alice = address(10);
  address bob = address(20);
  address charlie = address(30);

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

    autofarmERC4626 = new AutofarmERC4626();
    autofarmERC4626.initialize(
      ERC20Upgradeable(address(testToken)),
      FlywheelCore(address(flywheel)),
      0,
      ERC20Upgradeable(address(autoToken)),
      IAutofarmV2(address(mockAutofarm))
    );
    marketKey = ERC20(address(autofarmERC4626));
    flywheel.addStrategyForRewards(marketKey);

    // Add mockStrategy to Autofarm
    mockAutofarm.add(ERC20(address(testToken)), 1, address(mockStrategy));
    vm.warp(2);
    vm.roll(2);
  }

  function testInitializedValues() public {
    assertEq(autofarmERC4626.name(), "Midas TestToken Vault");
    assertEq(autofarmERC4626.symbol(), "mvTST");
    assertEq(address(autofarmERC4626.asset()), address(testToken));
    assertEq(address(autofarmERC4626.autofarm()), address(mockAutofarm));
    assertEq(address(marketKey), address(autofarmERC4626));
    assertEq(testToken.allowance(address(autofarmERC4626), address(mockAutofarm)), type(uint256).max);
    assertEq(autoToken.allowance(address(autofarmERC4626), address(flywheelRewards)), type(uint256).max);
  }

  function deposit(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of underlying token of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(autofarmERC4626), amount);
    autofarmERC4626.deposit(amount, user);
    vm.stopPrank();
  }

  function mint(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of underlying token of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(autofarmERC4626), amount);
    autofarmERC4626.mint(autofarmERC4626.previewDeposit(amount), user);
    vm.stopPrank();
  }

  function testTheBugWithdraw(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 100 && amount < 1e19);
    testToken.mint(alice, 100e18);

    deposit(bob, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(bob), 0, "should deposit the full balance of underlying token of user");
    assertEq(
      testToken.balanceOf(address(autofarmERC4626)),
      0,
      "should deposit the full balance of underlying token of user"
    );

    // just testing if other users depositing would mess up the calcs
    mint(charlie, amount);

    // test if the shares of the autofarmERC4626 equal to the assets deposited
    uint256 autofarmERC4626SharesMintedToBob = autofarmERC4626.balanceOf(bob);
    assertEq(
      autofarmERC4626SharesMintedToBob,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(bob);
      uint256 assetsToWithdraw = amount / 2;
      autofarmERC4626.withdraw(assetsToWithdraw, bob, bob);
      uint256 assetsWithdrawn = testToken.balanceOf(bob);
      assertTrue(
        diff(assetsWithdrawn, assetsToWithdraw) < 100,
        "the assets withdrawn must be almost equal to the requested assets to withdraw"
      );
      vm.stopPrank();
    }

    uint256 lockedFunds = testToken.balanceOf(address(autofarmERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the autofarmERC4626
    assertEq(
      lockedFunds,
      0,
      "should transfer the full balance of the withdrawn underlying token, no dust is acceptable"
    );
  }

  function testTheBugRedeem(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 1e5 && amount < 1e19);
    testToken.mint(alice, 100e18);

    deposit(charlie, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(charlie), 0, "should deposit the full balance of underlying token of user");
    assertEq(
      testToken.balanceOf(address(autofarmERC4626)),
      0,
      "should deposit the full balance of underlying token of user"
    );

    // just testing if other users depositing would mess up the calcs
    mint(bob, amount);

    // test if the shares of the autofarmERC4626 equal to the assets deposited
    uint256 autofarmERC4626SharesMintedToCharlie = autofarmERC4626.balanceOf(charlie);
    assertEq(
      autofarmERC4626SharesMintedToCharlie,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(charlie);
      uint256 autofarERC4626SharesToRedeem = autofarmERC4626.balanceOf(charlie);
      autofarmERC4626.redeem(autofarERC4626SharesToRedeem, charlie, charlie);
      uint256 assetsRedeemed = testToken.balanceOf(charlie);
      uint256 assetsToRedeem = autofarmERC4626.previewRedeem(autofarERC4626SharesToRedeem);
      {
        emit log_uint(assetsRedeemed);
        emit log_uint(assetsToRedeem);
      }
      assertTrue(
        diff(assetsRedeemed, assetsToRedeem) * 1e4 < amount,
        "the assets redeemed must be almost equal to the requested assets to redeem"
      );
      vm.stopPrank();
    }

    uint256 lockedFunds = testToken.balanceOf(address(autofarmERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the autofarmERC4626
    assertEq(
      lockedFunds,
      0,
      "should transfer the full balance of the redeemed underlying token, no dust is acceptable"
    );
  }

  function deposit() public {
    testToken.mint(address(this), depositAmount);
    testToken.approve(address(autofarmERC4626), depositAmount);
    // flywheelPreSupplierAction -- usually this would be done in Comptroller when supplying
    flywheel.accrue(ERC20(address(autofarmERC4626)), address(this));
    autofarmERC4626.deposit(depositAmount, address(this));
    // flywheelPreSupplierAction
    flywheel.accrue(ERC20(address(autofarmERC4626)), address(this));
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
    flywheel.accrue(ERC20(address(autofarmERC4626)), address(this));
    vm.warp(4);
    vm.roll(4);

    flywheel.accrue(ERC20(address(autofarmERC4626)), address(this));
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
    flywheel.accrue(ERC20(address(autofarmERC4626)), address(this));
    vm.warp(4);
    vm.roll(4);

    flywheel.accrue(ERC20(address(autofarmERC4626)), address(this), tester);
    flywheel.claimRewards(address(this));
    flywheel.claimRewards(tester);

    assertEq(autoToken.balanceOf(address(this)), (rewardsStream / 2) - 1);
    assertEq(autoToken.balanceOf(address(this)), (rewardsStream / 2) - 1);
    assertEq(autoToken.balanceOf(address(flywheel)), 0);
  }
}
