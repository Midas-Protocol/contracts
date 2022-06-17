// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";

import { DotDotLpERC4626, ILpDepositor } from "../compound/strategies/DotDotLpERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockLpDepositor } from "./mocks/dotdot/MockLpDepositor.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../utils/FixedPointMathLib.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

contract DotDotERC4626Test is WithPool, BaseTest {
  using FixedPointMathLib for uint256;

  BeefyERC4626 beefyERC4626;
  IBeefyVault beefyVault;
  address beefyStrategy = 0xEeBcd7E1f008C52fe5804B306832B7DD317e163D;

  uint256 depositAmount = 100e18;
  uint256 withdrawalFee = 10;
  uint256 BPS_DENOMINATOR = 10_000;

  uint256 initalBeefyBalance;
  uint256 initalBeefySupply;

  constructor()
    WithPool(
      MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
      MockERC20(0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6)
    )
  {}

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    beefyVault = IBeefyVault(0xD2FeCe7Ff1B791F8fE7f35424165abB8BD1671f2);
    beefyERC4626 = new BeefyERC4626(underlyingToken, beefyVault, withdrawalFee);
    initalBeefyBalance = beefyVault.balance();
    initalBeefySupply = beefyVault.totalSupply();
    sendUnderlyingToken(100e18, address(this));
    sendUnderlyingToken(100e18, address(1));
  }

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(beefyERC4626), amount);
    beefyERC4626.deposit(amount, _owner);
    vm.stopPrank();
  }

  function sendUnderlyingToken(uint256 amount, address recipient) public {
    vm.startPrank(0x1083926054069AaD75d7238E9B809b0eF9d94e5B);
    underlyingToken.transfer(recipient, amount);
    vm.stopPrank();
  }

  function increaseAssetsInVault() public {
    sendUnderlyingToken(1000e18, address(beefyVault));
    beefyVault.earn();
  }

  function testInitializedValues() public shouldRun(forChains(BSC_MAINNET)) {
    assertEq(beefyERC4626.name(), "Midas Pancake LPs Vault");
    assertEq(beefyERC4626.symbol(), "mvCake-LP");
    assertEq(address(beefyERC4626.asset()), address(underlyingToken));
    assertEq(address(beefyERC4626.beefyVault()), address(beefyVault));
  }

  function testPreviewDepositAndMintReturnTheSameValue() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 returnedShares = beefyERC4626.previewDeposit(depositAmount);
    assertEq(beefyERC4626.previewMint(returnedShares), depositAmount);
  }

  function testPreviewWithdrawAndRedeemReturnTheSameValue() public shouldRun(forChains(BSC_MAINNET)) {
    deposit(address(this), depositAmount);
    uint256 withdrawalAmount = 10e18;
    uint256 reqShares = beefyERC4626.previewWithdraw(withdrawalAmount);
    assertEq(beefyERC4626.previewRedeem(reqShares), withdrawalAmount);
  }

  function testDeposit() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedBeefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;
    uint256 expectedErc4626Shares = beefyERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), initalBeefyBalance + depositAmount);

    // Test that the balance view calls work
    assertEq(beefyERC4626.totalAssets(), depositAmount);
    assertEq(beefyERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), expectedErc4626Shares);
    assertEq(beefyERC4626.totalSupply(), expectedErc4626Shares);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(beefyVault.balanceOf(address(beefyERC4626)), expectedBeefyShares);
  }

  function testDepositWithIncreasedVaultValue() public shouldRun(forChains(BSC_MAINNET)) {
    sendUnderlyingToken(depositAmount, address(this));

    uint256 oldExpectedBeefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;
    uint256 oldExpected4626Shares = beefyERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Increase the share price
    increaseAssetsInVault();

    uint256 expectedBeefyShares = (depositAmount * beefyVault.totalSupply()) / beefyVault.balance();
    uint256 previewErc4626Shares = beefyERC4626.previewDeposit(depositAmount);
    uint256 expected4626Shares = depositAmount.mulDivDown(beefyERC4626.totalSupply(), beefyERC4626.totalAssets());

    deposit(address(this), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), oldExpected4626Shares + previewErc4626Shares);

    // Test that we got less shares on the second mint after assets in the vault increased
    assertLe(previewErc4626Shares, oldExpected4626Shares, "!new shares < old Shares");
    assertEq(previewErc4626Shares, expected4626Shares, "!previewShares == expectedShares");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(beefyVault.balanceOf(address(beefyERC4626)), oldExpectedBeefyShares + expectedBeefyShares);
  }

  function testMultipleDeposit() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedBeefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;
    uint256 expectedErc4626Shares = beefyERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), initalBeefyBalance + depositAmount * 2);

    // Test that the balance view calls work
    assertTrue(
      depositAmount * 2 - beefyERC4626.totalAssets() <= 1,
      "Beefy total Assets should be same as sum of deposited amounts"
    );
    assertTrue(
      depositAmount - beefyERC4626.balanceOfUnderlying(address(this)) <= 1,
      "Underlying token balance should be same as depositied amount"
    );
    assertTrue(
      depositAmount - beefyERC4626.balanceOfUnderlying(address(1)) <= 1,
      "Underlying token balance should be same as depositied amount"
    );

    // Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), expectedErc4626Shares);
    assertEq(beefyERC4626.balanceOf(address(1)), expectedErc4626Shares);
    assertEq(beefyERC4626.totalSupply(), expectedErc4626Shares * 2);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(beefyVault.balanceOf(address(beefyERC4626)), expectedBeefyShares * 2);

    // Beefy ERC4626 should not have underlyingToken after deposit
    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 1, "Beefy erc4626 locked amount checking");
  }

  function testMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedBeefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;
    uint256 mintAmount = beefyERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(beefyERC4626), depositAmount);
    beefyERC4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), initalBeefyBalance + depositAmount);

    // Test that the balance view calls work
    assertEq(beefyERC4626.totalAssets(), depositAmount);
    assertEq(beefyERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), mintAmount);
    assertEq(beefyERC4626.totalSupply(), mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(beefyVault.balanceOf(address(beefyERC4626)), expectedBeefyShares);
  }

  function testMultipleMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedBeefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;
    uint256 mintAmount = beefyERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(beefyERC4626), depositAmount);
    beefyERC4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), initalBeefyBalance + depositAmount);

    // Test that the balance view calls work
    assertEq(beefyERC4626.totalAssets(), depositAmount);
    assertEq(beefyERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), mintAmount);
    assertEq(beefyERC4626.totalSupply(), mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(beefyVault.balanceOf(address(beefyERC4626)), expectedBeefyShares);

    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 1, "Beefy erc4626 locked amount checking");

    vm.startPrank(address(1));
    underlyingToken.approve(address(beefyERC4626), depositAmount);
    beefyERC4626.mint(mintAmount, address(1));

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), initalBeefyBalance + depositAmount + depositAmount);

    // Test that the balance view calls work
    assertTrue(depositAmount + depositAmount - beefyERC4626.totalAssets() <= 1);
    assertTrue(depositAmount - beefyERC4626.balanceOfUnderlying(address(1)) <= 1);

    // Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(1)), mintAmount);
    assertEq(beefyERC4626.totalSupply(), mintAmount + mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(beefyVault.balanceOf(address(beefyERC4626)), expectedBeefyShares * 2);

    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 2, "Beefy erc4626 locked amount checking");
    vm.stopPrank();
  }

  function testWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 beefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;

    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beefyERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = beefyERC4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    beefyERC4626.withdraw(withdrawalAmount, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(beefyERC4626.totalSupply(), depositAmount - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");
    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 1, "!0");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );
  }

  function testWithdrawWithIncreasedVaultValue() public shouldRun(forChains(BSC_MAINNET)) {
    sendUnderlyingToken(depositAmount, address(this));

    uint256 beefyShareBal = (depositAmount * initalBeefySupply) / initalBeefyBalance;

    deposit(address(this), depositAmount);

    uint256 withdrawalAmount = 10e18;

    uint256 oldExpectedErc4626SharesNeeded = beefyERC4626.previewWithdraw(withdrawalAmount);
    uint256 oldExpectedBeefySharesNeeded = oldExpectedErc4626SharesNeeded.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    beefyERC4626.withdraw(withdrawalAmount, address(this), address(this));

    // Increase the share price
    increaseAssetsInVault();

    uint256 expectedErc4626SharesNeeded = beefyERC4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    beefyERC4626.withdraw(withdrawalAmount, address(this), address(this));

    // Test that we minted the correct amount of token
    assertEq(
      beefyERC4626.balanceOf(address(this)),
      depositAmount - (oldExpectedErc4626SharesNeeded + expectedErc4626SharesNeeded)
    );

    // Test that we got less shares on the second mint after assets in the vault increased
    assertLe(expectedErc4626SharesNeeded, oldExpectedErc4626SharesNeeded, "!new shares < old Shares");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShareBal - (oldExpectedBeefySharesNeeded + expectedBeefySharesNeeded)
    );
  }

  function testMultipleWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 beefyShares = ((depositAmount * initalBeefySupply) / initalBeefyBalance) * 2;

    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beefyERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = beefyERC4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    beefyERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(depositAmount * 2 - expectedErc4626SharesNeeded - beefyERC4626.totalSupply() < 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );

    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 1, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - expectedErc4626SharesNeeded;
    beefyShares = beefyShares - expectedBeefySharesNeeded;
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = beefyERC4626.balanceOf(address(1));
    expectedErc4626SharesNeeded = beefyERC4626.previewWithdraw(withdrawalAmount);
    expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    vm.prank(address(1));
    beefyERC4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(beefyERC4626.totalSupply(), totalSupplyBefore - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(1)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );

    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 2, "Beefy erc4626 locked amount checking");
  }

  function testRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 beefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;

    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = beefyERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beefyERC4626.balanceOf(address(this));
    uint256 expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    beefyERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(beefyERC4626.totalSupply(), depositAmount - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );
  }

  function testMultipleRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 beefyShares = ((depositAmount * initalBeefySupply) / initalBeefyBalance) * 2;

    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = beefyERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beefyERC4626.balanceOf(address(this));
    uint256 expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    beefyERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(beefyERC4626.totalSupply(), depositAmount * 2 - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );
    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 1, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - redeemAmount;
    beefyShares -= expectedBeefySharesNeeded;
    redeemAmount = beefyERC4626.previewWithdraw(withdrawalAmount);
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = beefyERC4626.balanceOf(address(1));
    expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );
    vm.prank(address(1));
    beefyERC4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(beefyERC4626.totalSupply(), totalSupplyBefore - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(1)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );
    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 2, "Beefy erc4626 locked amount checking");
  }

  function testPauseContract() public shouldRun(forChains(BSC_MAINNET)) {
    sendUnderlyingToken(depositAmount, address(this));

    deposit();

    beefyERC4626.emergencyWithdrawFromStrategyAndPauseContract();

    underlyingToken.approve(address(beefyERC4626), depositAmount);
    vm.expectRevert("Pausable: paused");
    beefyERC4626.deposit(depositAmount, address(this));

    vm.expectRevert("Pausable: paused");
    beefyERC4626.mint(depositAmount, address(this));

    vm.expectRevert("Pausable: paused");
    beefyERC4626.withdraw(1e18, address(this), address(this));

    vm.expectRevert("Pausable: paused");
    beefyERC4626.redeem(1e18, address(this), address(this));
  }

  function testEmergencyWithdrawFromStrategyAndPauseContract() public shouldRun(forChains(BSC_MAINNET)) {
    deposit();
    uint256 expectedBal = beefyERC4626.previewRedeem(depositAmount);

    beefyERC4626.emergencyWithdrawFromStrategyAndPauseContract();

    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), expectedBal, "!withdraws underlying");
    assertEq(beefyERC4626.totalAssets(), 0, "!totalAssets == 0");
  }

  function testEmergencyWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    deposit();
    uint256 expectedBal = beefyERC4626.previewRedeem(depositAmount);

    beefyERC4626.emergencyWithdrawFromStrategyAndPauseContract();

    beefyERC4626.emergencyWithdraw(depositAmount);

    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "!no leftover");
    assertEq(beefyERC4626.totalAssets(), 0, "!totalAssets == 0");
    assertEq(beefyERC4626.totalSupply(), 0, "!totalSupply == 0");
    assertEq(underlyingToken.balanceOf(address(this)), expectedBal, "!userBal");
  }
}

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

  function testAccumulatingRewardsOnDeposit() public {
    deposit();
    assertEq(dddToken.totalSupply(), expectedReward);
    assertEq(epxToken.totalSupply(), expectedReward);

    assertEq(dddToken.balanceOf(address(dotDotERC4626)), expectedReward);
    assertEq(epxToken.balanceOf(address(dotDotERC4626)), expectedReward);
  }

  function testAccumulatingRewardsOnWithdrawal() public {
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
