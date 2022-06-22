// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "./config/BaseTest.t.sol";
import "../compound/strategies/BeamERC4626.sol";
import "./mocks/beam/MockVault.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

contract MockBoringERC20 is MockERC20 {
  constructor(
    string memory name,
    string memory symbol,
    uint8 decimal
  ) MockERC20(name, symbol, decimal) {}

  function safeTransferFrom(
    address from,
    address to,
    uint256 amount
  ) public {
    transferFrom(from, to, amount);
  }

  function safeTransfer(address to, uint256 amount) public {
    transfer(to, amount);
  }
}

contract BeamERC4626Test is BaseTest {
  using stdStorage for StdStorage;
  BeamERC4626 beamErc4626;
  MockVault mockBeamChef;
  MockBoringERC20 testToken;
  MockERC20 glintToken;
  ERC20 marketKey;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;

  uint256 depositAmount = 100;

  address alice = address(10);
  address bob = address(20);
  address charlie = address(30);

  function setUp() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    testToken = MockBoringERC20(0x99588867e817023162F4d4829995299054a5fC57);
    glintToken = MockERC20(0xcd3B51D98478D53F4515A306bE565c6EebeF1D58);
    mockBeamChef = new MockVault(IBoringERC20(address(testToken)), 0, address(0), 0, address(0));
    vm.warp(1);
    vm.roll(1);

    flywheel = new FlywheelCore(
      glintToken,
      FlywheelDynamicRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );

    flywheelRewards = new FuseFlywheelDynamicRewards(flywheel, 1);
    flywheel.setFlywheelRewards(flywheelRewards);

    beamErc4626 = new BeamERC4626(testToken, flywheel, 0, glintToken, IVault(address(mockBeamChef)));
    marketKey = ERC20(address(beamErc4626));
    flywheel.addStrategyForRewards(marketKey);

    IMultipleRewards[] memory rewarders = new IMultipleRewards[](0);
    mockBeamChef.add(1, IBoringERC20(address(testToken)), 0, 0, rewarders);
    vm.warp(2);
    vm.roll(2);
  }

  function testInitializedValues() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    assertEq(beamErc4626.name(), testToken.name());
    assertEq(beamErc4626.symbol(), testToken.symbol());
    assertEq(address(beamErc4626.asset()), address(testToken));
    assertEq(address(beamErc4626.VAULT()), address(mockBeamChef));
    assertEq(address(marketKey), address(beamErc4626));
    assertEq(testToken.allowance(address(beamErc4626), address(mockBeamChef)), type(uint256).max);
    assertEq(glintToken.allowance(address(beamErc4626), address(flywheelRewards)), type(uint256).max);
  }

  function deposit(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of cakeLP of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(beamErc4626), amount);
    beamErc4626.deposit(amount, user);
    vm.stopPrank();
  }

  function mint(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of cakeLP of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(beamErc4626), amount);
    beamErc4626.mint(beamErc4626.previewDeposit(amount), user);
    vm.stopPrank();
  }

  function testTheBugWithdraw(uint256 amount) public shouldRun(forChains(MOONBEAM_MAINNET)) {
    vm.assume(amount > 100 && amount < 1e19);
    vm.prank(0x33Ad49856da25b8E2E2D762c411AEda0D1727918);
    testToken.approve(0x33Ad49856da25b8E2E2D762c411AEda0D1727918, 100e18);
    vm.prank(0x33Ad49856da25b8E2E2D762c411AEda0D1727918);
    testToken.transferFrom(0x33Ad49856da25b8E2E2D762c411AEda0D1727918, alice, 100e18);

    deposit(bob, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(bob), 0, "should deposit the full balance of cakeLP of user");
    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "should deposit the full balance of cakeLP of user");

    // just testing if other users depositing would mess up the calcs
    mint(charlie, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToBob = beamErc4626.balanceOf(bob);
    assertEq(
      beefyERC4626SharesMintedToBob,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(bob);
      uint256 assetsToWithdraw = amount / 2;
      beamErc4626.withdraw(assetsToWithdraw, bob, bob);
      uint256 assetsWithdrawn = testToken.balanceOf(bob);
      assertTrue(
        diff(assetsWithdrawn, assetsToWithdraw) < 100,
        "the assets withdrawn must be almost equal to the requested assets to withdraw"
      );
      vm.stopPrank();
    }

    uint256 lockedFunds = testToken.balanceOf(address(beamErc4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the withdrawn cakeLP, no dust is acceptable");
  }

  function testTheBugRedeem(uint256 amount) public shouldRun(forChains(MOONBEAM_MAINNET)) {
    vm.assume(amount > 1e5 && amount < 1e19);
    vm.prank(0x33Ad49856da25b8E2E2D762c411AEda0D1727918);
    testToken.approve(0x33Ad49856da25b8E2E2D762c411AEda0D1727918, 100e18);
    vm.prank(0x33Ad49856da25b8E2E2D762c411AEda0D1727918);
    testToken.transferFrom(0x33Ad49856da25b8E2E2D762c411AEda0D1727918, alice, 100e18);

    deposit(charlie, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(charlie), 0, "should deposit the full balance of cakeLP of user");
    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "should deposit the full balance of cakeLP of user");

    // just testing if other users depositing would mess up the calcs
    mint(bob, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToCharlie = beamErc4626.balanceOf(charlie);
    assertEq(
      beefyERC4626SharesMintedToCharlie,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(charlie);
      uint256 beefyERC4626SharesToRedeem = beamErc4626.balanceOf(charlie);
      beamErc4626.redeem(beefyERC4626SharesToRedeem, charlie, charlie);
      uint256 assetsRedeemed = testToken.balanceOf(charlie);
      uint256 assetsToRedeem = beamErc4626.previewRedeem(beefyERC4626SharesToRedeem);
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

    uint256 lockedFunds = testToken.balanceOf(address(beamErc4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the redeemed cakeLP, no dust is acceptable");
  }

  function _deposit() internal {
    vm.prank(0x457C5B8A6224F524d9f15fA6B6d70fCad8EBa623);
    testToken.approve(0x457C5B8A6224F524d9f15fA6B6d70fCad8EBa623, depositAmount);
    vm.prank(0x457C5B8A6224F524d9f15fA6B6d70fCad8EBa623);
    testToken.transferFrom(0x457C5B8A6224F524d9f15fA6B6d70fCad8EBa623, address(this), depositAmount);
    uint256 balance = testToken.balanceOf(address(this));
    testToken.approve(address(beamErc4626), depositAmount);
    flywheel.accrue(ERC20(beamErc4626), address(this));
    beamErc4626.deposit(depositAmount, address(this));
    flywheel.accrue(ERC20(beamErc4626), address(this));
  }

  function testDeposit() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    _deposit();

    assertEq(testToken.balanceOf(address(this)), 0);
    assertEq(testToken.balanceOf(address(mockBeamChef)), depositAmount);

    // //Test that the balance view calls work
    assertEq(beamErc4626.totalAssets(), depositAmount);
    assertEq(beamErc4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    _deposit();
    beamErc4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), depositAmount);
    assertEq(testToken.balanceOf(address(mockBeamChef)), 0);

    // //Test that we burned the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), 0);
  }
}
