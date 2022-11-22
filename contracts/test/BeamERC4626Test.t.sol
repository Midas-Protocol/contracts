// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "../midas/strategies/BeamERC4626.sol";
import "./mocks/beam/MockVault.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

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
  using FixedPointMathLib for uint256;

  BeamERC4626 beamErc4626;
  MockVault mockBeamChef;
  ERC20Upgradeable testToken;
  MockERC20 glintToken;
  ERC20 marketKey;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;

  uint256 depositAmount = 100e18;
  address joy = 0x33Ad49856da25b8E2E2D762c411AEda0D1727918;

  uint256 initialBeamBalance = 0;
  uint256 initialBeamSupply = 0;

  // TODO adapt the test to run it on the latest block
  function setUp() public forkAtBlock(MOONBEAM_MAINNET, 1824921) {
    testToken = ERC20Upgradeable(0x99588867e817023162F4d4829995299054a5fC57);
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

    beamErc4626 = new BeamERC4626();
    beamErc4626.initialize(testToken, flywheel, 0, IVault(address(mockBeamChef)));
    marketKey = ERC20(address(beamErc4626));
    flywheel.addStrategyForRewards(marketKey);

    IMultipleRewards[] memory rewarders = new IMultipleRewards[](0);
    mockBeamChef.add(1, IBoringERC20(address(testToken)), 0, 0, rewarders);

    vm.warp(2);
    vm.roll(2);

    sendUnderlyingToken(100e18, address(this));
    sendUnderlyingToken(100e18, address(1));
  }

  function sendUnderlyingToken(uint256 amount, address recipient) public {
    vm.startPrank(joy);
    testToken.transfer(recipient, amount);
    vm.stopPrank();
  }

  function getBeamCheckBalance() internal view returns (uint256) {
    (IBoringERC20 lpToken, , , , , , ) = mockBeamChef.poolInfo(0);
    return lpToken.balanceOf(address(mockBeamChef));
  }

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    testToken.approve(address(beamErc4626), amount);
    beamErc4626.deposit(amount, _owner);
    vm.stopPrank();
  }

  function testDeposit() public {
    uint256 expectedErc4626Shares = beamErc4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Test that the actual transfers worked
    assertEq(getBeamCheckBalance(), depositAmount);

    // Test that the balance view calls work
    assertEq(beamErc4626.totalAssets(), depositAmount);
    assertEq(beamErc4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), expectedErc4626Shares);
    assertEq(beamErc4626.totalSupply(), expectedErc4626Shares);
  }

  function testMultipleDeposit() public {
    uint256 expectedErc4626Shares = beamErc4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    // Test that the actual transfers worked
    assertEq(getBeamCheckBalance(), initialBeamBalance + depositAmount * 2);

    // Test that the balance view calls work
    assertTrue(
      depositAmount * 2 - beamErc4626.totalAssets() <= 1,
      "Beam total Assets should be same as sum of deposited amounts"
    );
    assertTrue(
      depositAmount - beamErc4626.balanceOfUnderlying(address(this)) <= 1,
      "Underlying token balance should be same as depositied amount"
    );
    assertTrue(
      depositAmount - beamErc4626.balanceOfUnderlying(address(1)) <= 1,
      "Underlying token balance should be same as depositied amount"
    );

    // Test that we minted the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), expectedErc4626Shares);
    assertEq(beamErc4626.balanceOf(address(1)), expectedErc4626Shares);
    assertEq(beamErc4626.totalSupply(), expectedErc4626Shares * 2);

    // Beam ERC4626 should not have underlyingToken after deposit
    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "Beam erc4626 locked amount checking");
  }

  function testMint() public {
    uint256 mintAmount = beamErc4626.previewDeposit(depositAmount);

    testToken.approve(address(beamErc4626), depositAmount);
    beamErc4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(getBeamCheckBalance(), initialBeamBalance + depositAmount);

    // Test that the balance view calls work
    assertEq(beamErc4626.totalAssets(), depositAmount);
    assertEq(beamErc4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), mintAmount);
    assertEq(beamErc4626.totalSupply(), mintAmount);
  }

  function testMultipleMint() public {
    uint256 mintAmount = beamErc4626.previewDeposit(depositAmount);

    testToken.approve(address(beamErc4626), depositAmount);
    beamErc4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(getBeamCheckBalance(), initialBeamBalance + depositAmount);

    // Test that the balance view calls work
    assertEq(beamErc4626.totalAssets(), depositAmount);
    assertEq(beamErc4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), mintAmount);
    assertEq(beamErc4626.totalSupply(), mintAmount);

    assertTrue(testToken.balanceOf(address(beamErc4626)) <= 1, "Beam erc4626 locked amount checking");

    vm.startPrank(address(1));
    testToken.approve(address(beamErc4626), depositAmount);
    beamErc4626.mint(mintAmount, address(1));

    // Test that the actual transfers worked
    assertEq(getBeamCheckBalance(), initialBeamBalance + depositAmount + depositAmount);

    // Test that the balance view calls work
    assertTrue(depositAmount + depositAmount - beamErc4626.totalAssets() <= 1);
    assertTrue(depositAmount - beamErc4626.balanceOfUnderlying(address(1)) <= 1);

    // Test that we minted the correct amount of token
    assertEq(beamErc4626.balanceOf(address(1)), mintAmount);
    assertEq(beamErc4626.totalSupply(), mintAmount + mintAmount);

    assertTrue(testToken.balanceOf(address(beamErc4626)) <= 2, "Beam erc4626 locked amount checking");
    vm.stopPrank();
  }

  function testWithdraw() public {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);

    uint256 assetBalBefore = testToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beamErc4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = beamErc4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeamSharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      getBeamCheckBalance(),
      beamErc4626.totalSupply()
    );

    beamErc4626.withdraw(withdrawalAmount, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(diff(testToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

    assertEq(beamErc4626.totalSupply(), depositAmount - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beamErc4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");
    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "Beam erc4626 locked amount checking");
  }

  function testMultipleWithdraw() public {
    uint256 BeamShares = depositAmount * 2;

    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    uint256 assetBalBefore = testToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beamErc4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = beamErc4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeamSharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      getBeamCheckBalance(),
      beamErc4626.totalSupply()
    );

    beamErc4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(diff(testToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

    assertTrue(depositAmount * 2 - expectedErc4626SharesNeeded - beamErc4626.totalSupply() < 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beamErc4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of Beam shares
    assertEq(getBeamCheckBalance(), BeamShares - expectedBeamSharesNeeded, "!Beam share balance");

    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "Beam erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - expectedErc4626SharesNeeded;
    BeamShares = BeamShares - expectedBeamSharesNeeded;
    assetBalBefore = testToken.balanceOf(address(1));
    erc4626BalBefore = beamErc4626.balanceOf(address(1));
    expectedErc4626SharesNeeded = beamErc4626.previewWithdraw(withdrawalAmount);
    expectedBeamSharesNeeded = expectedErc4626SharesNeeded.mulDivUp(getBeamCheckBalance(), beamErc4626.totalSupply());

    vm.prank(address(1));
    beamErc4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertTrue(diff(testToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

    assertEq(beamErc4626.totalSupply(), totalSupplyBefore - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beamErc4626.balanceOf(address(1)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of Beam shares
    assertEq(getBeamCheckBalance(), BeamShares - expectedBeamSharesNeeded, "!Beam share balance");

    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "Beam erc4626 locked amount checking");
  }

  function testRedeem() public {
    uint256 BeamShares = depositAmount;
    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = beamErc4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);

    uint256 assetBalBefore = testToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beamErc4626.balanceOf(address(this));
    uint256 expectedBeamSharesNeeded = redeemAmount.mulDivUp(getBeamCheckBalance(), beamErc4626.totalSupply());

    beamErc4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(diff(testToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

    assertEq(beamErc4626.totalSupply(), depositAmount - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beamErc4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of Beam shares
    assertEq(getBeamCheckBalance(), BeamShares - expectedBeamSharesNeeded, "!Beam share balance");
  }

  function testMultipleRedeem() public {
    uint256 BeamShares = depositAmount * 2;

    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = beamErc4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    uint256 assetBalBefore = testToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beamErc4626.balanceOf(address(this));
    uint256 expectedBeamSharesNeeded = redeemAmount.mulDivUp(getBeamCheckBalance(), beamErc4626.totalSupply());

    beamErc4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(diff(testToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

    // Test that the balance view calls work
    assertEq(beamErc4626.totalSupply(), depositAmount * 2 - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beamErc4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of Beam shares
    assertEq(getBeamCheckBalance(), BeamShares - expectedBeamSharesNeeded, "!Beam share balance");
    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "Beam erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - redeemAmount;
    BeamShares -= expectedBeamSharesNeeded;
    redeemAmount = beamErc4626.previewWithdraw(withdrawalAmount);
    assetBalBefore = testToken.balanceOf(address(1));
    erc4626BalBefore = beamErc4626.balanceOf(address(1));
    expectedBeamSharesNeeded = redeemAmount.mulDivUp(getBeamCheckBalance(), beamErc4626.totalSupply());
    vm.prank(address(1));
    beamErc4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertTrue(diff(testToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

    // Test that the balance view calls work
    assertEq(beamErc4626.totalSupply(), totalSupplyBefore - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beamErc4626.balanceOf(address(1)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of Beam shares
    assertEq(getBeamCheckBalance(), BeamShares - expectedBeamSharesNeeded, "!Beam share balance");
    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "Beam erc4626 locked amount checking");
  }

  function testPauseContract() public {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    beamErc4626.emergencyWithdrawAndPause();

    testToken.approve(address(beamErc4626), depositAmount);
    vm.expectRevert("Pausable: paused");
    beamErc4626.deposit(depositAmount, address(this));

    vm.expectRevert("Pausable: paused");
    beamErc4626.mint(depositAmount, address(this));

    uint256 expectedSharesNeeded = withdrawAmount.mulDivDown(beamErc4626.totalSupply(), beamErc4626.totalAssets());
    beamErc4626.withdraw(withdrawAmount, address(this), address(this));

    assertEq(beamErc4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded, "!withdraw share bal");
    assertEq(testToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(beamErc4626.totalAssets(), beamErc4626.totalSupply());
    beamErc4626.redeem(withdrawAmount, address(this), address(this));

    assertEq(
      beamErc4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      "!redeem share bal"
    );
    assertEq(testToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }

  function testEmergencyWithdrawAndPause() public {
    deposit(address(this), depositAmount);

    uint256 expectedBal = beamErc4626.previewRedeem(depositAmount);
    assertEq(testToken.balanceOf(address(beamErc4626)), 0, "!init 0");

    beamErc4626.emergencyWithdrawAndPause();

    assertEq(testToken.balanceOf(address(beamErc4626)), expectedBal, "!withdraws underlying");
    assertEq(beamErc4626.totalAssets(), expectedBal, "!totalAssets == expectedBal");
  }

  function testEmergencyWithdrawAndRedeem() public {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    beamErc4626.emergencyWithdrawAndPause();

    uint256 expectedSharesNeeded = withdrawAmount.mulDivDown(beamErc4626.totalSupply(), beamErc4626.totalAssets());
    beamErc4626.withdraw(withdrawAmount, address(this), address(this));

    assertEq(beamErc4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded, "!withdraw share bal");
    assertEq(testToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(beamErc4626.totalAssets(), beamErc4626.totalSupply());
    beamErc4626.redeem(withdrawAmount, address(this), address(this));

    assertEq(
      beamErc4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      "!redeem share bal"
    );
    assertEq(testToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }
}

contract BeamERC4626UnitTest is BaseTest {
  BeamERC4626 beamErc4626;
  MockVault mockBeamChef;
  ERC20Upgradeable testToken;
  MockERC20 glintToken;
  ERC20 marketKey;
  FlywheelCore flywheel;
  FuseFlywheelDynamicRewards flywheelRewards;

  uint256 depositAmount = 100;

  address alice = address(10);
  address bob = address(20);
  address charlie = address(30);
  address joy = 0x33Ad49856da25b8E2E2D762c411AEda0D1727918;

  function setUp() public fork(MOONBEAM_MAINNET) {
    testToken = ERC20Upgradeable(0x99588867e817023162F4d4829995299054a5fC57);
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

    beamErc4626 = new BeamERC4626();
    beamErc4626.initialize(testToken, flywheel, 0, IVault(address(mockBeamChef)));
    marketKey = ERC20(address(beamErc4626));
    flywheel.addStrategyForRewards(marketKey);

    IMultipleRewards[] memory rewarders = new IMultipleRewards[](0);
    mockBeamChef.add(1, IBoringERC20(address(testToken)), 0, 0, rewarders);
    vm.warp(2);
    vm.roll(2);
  }

  function testInitializedValues() public {
    assertEq(
      beamErc4626.name(),
      string(abi.encodePacked("Midas ", testToken.name(), " Vault")),
      string(abi.encodePacked("!name ", testToken.name()))
    );
    assertEq(
      beamErc4626.symbol(),
      string(abi.encodePacked("mv", testToken.symbol())),
      string(abi.encodePacked("!symbol ", testToken.symbol()))
    );

    assertEq(address(beamErc4626.asset()), address(testToken));
    assertEq(address(beamErc4626.vault()), address(mockBeamChef));
    assertEq(address(marketKey), address(beamErc4626));
    assertEq(testToken.allowance(address(beamErc4626), address(mockBeamChef)), type(uint256).max);
    assertEq(glintToken.allowance(address(beamErc4626), address(flywheelRewards)), type(uint256).max);
  }

  function deposit(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of underlying token of user should equal amount");

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
    assertEq(testToken.balanceOf(user), amount, "the full balance of underlying token of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(beamErc4626), amount);
    beamErc4626.mint(beamErc4626.previewDeposit(amount), user);
    vm.stopPrank();
  }

  function testTheBugWithdraw(uint256 amount) public {
    vm.assume(amount > 100 && amount < 1e19);
    vm.prank(joy);
    testToken.approve(joy, 100e18);
    vm.prank(joy);
    testToken.transferFrom(joy, alice, 100e18);

    deposit(bob, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(bob), 0, "should deposit the full balance of underlying token of user");
    assertEq(
      testToken.balanceOf(address(beamErc4626)),
      0,
      "should deposit the full balance of underlying token of user"
    );

    // just testing if other users depositing would mess up the calcs
    mint(charlie, amount);

    // test if the shares of the beamErc4626 equal to the assets deposited
    uint256 beamErc4626SharesMintedToBob = beamErc4626.balanceOf(bob);
    assertEq(
      beamErc4626SharesMintedToBob,
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
    // check if any funds remained locked in the beamErc4626
    assertEq(
      lockedFunds,
      0,
      "should transfer the full balance of the withdrawn underlying token, no dust is acceptable"
    );
  }

  function testTheBugRedeem(uint256 amount) public {
    vm.assume(amount > 1e5 && amount < 1e19);
    vm.prank(joy);
    testToken.approve(joy, 100e18);
    vm.prank(joy);
    testToken.transferFrom(joy, alice, 100e18);

    deposit(charlie, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(charlie), 0, "should deposit the full balance of underlying token of user");
    assertEq(
      testToken.balanceOf(address(beamErc4626)),
      0,
      "should deposit the full balance of underlying token of user"
    );

    // just testing if other users depositing would mess up the calcs
    mint(bob, amount);

    // test if the shares of the beamErc4626 equal to the assets deposited
    uint256 beamErc4626SharesMintedToCharlie = beamErc4626.balanceOf(charlie);
    assertEq(
      beamErc4626SharesMintedToCharlie,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(charlie);
      uint256 beamErc4626SharesToRedeem = beamErc4626.balanceOf(charlie);
      beamErc4626.redeem(beamErc4626SharesToRedeem, charlie, charlie);
      uint256 assetsRedeemed = testToken.balanceOf(charlie);
      uint256 assetsToRedeem = beamErc4626.previewRedeem(beamErc4626SharesToRedeem);
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
    // check if any funds remained locked in the beamErc4626
    assertEq(
      lockedFunds,
      0,
      "should transfer the full balance of the redeemed underlying token, no dust is acceptable"
    );
  }

  function _deposit() internal {
    vm.prank(joy);
    testToken.approve(joy, depositAmount);
    vm.prank(joy);
    testToken.transferFrom(joy, address(this), depositAmount);
    testToken.approve(address(beamErc4626), testToken.balanceOf(address(this)));
    flywheel.accrue(ERC20(address(beamErc4626)), address(this));
    beamErc4626.deposit(depositAmount, address(this));
    flywheel.accrue(ERC20(address(beamErc4626)), address(this));
  }

  function testDeposit() public {
    _deposit();

    assertEq(testToken.balanceOf(address(this)), 0);
    assertEq(testToken.balanceOf(address(mockBeamChef)), depositAmount);

    // //Test that the balance view calls work
    assertEq(beamErc4626.totalAssets(), depositAmount);
    assertEq(beamErc4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public {
    _deposit();
    beamErc4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), depositAmount);
    assertEq(testToken.balanceOf(address(mockBeamChef)), 0);

    // //Test that we burned the correct amount of token
    assertEq(beamErc4626.balanceOf(address(this)), 0);
  }
}
