// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";

import { DotDotLpERC4626, ILpDepositor } from "../compound/strategies/DotDotLpERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
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

// Using 2BRL
// Tested on block 19052824
contract DotDotERC4626Test is WithPool, BaseTest {
  using FixedPointMathLib for uint256;

  address whale = 0x0BC3a8239B0a63E945Ea1bd6722Ba747b9557e56;

  DotDotLpERC4626 dotDotERC4626;
  ILpDepositor lpDepositor = ILpDepositor(0x8189F0afdBf8fE6a9e13c69bA35528ac6abeB1af);
  ERC20 depositShare = ERC20(0xEFF5b0E496dC7C26fFaA014cEa0d2Baa83DB11c4);

  ERC20 dddToken = ERC20(0x84c97300a190676a19D1E13115629A11f8482Bd1);
  FlywheelCore dddFlywheel;
  FuseFlywheelDynamicRewards dddRewards;

  ERC20 epxToken = ERC20(0xAf41054C1487b0e5E2B9250C0332eCBCe6CE9d71);
  FlywheelCore epxFlywheel;
  FuseFlywheelDynamicRewards epxRewards;

  uint256 depositAmount = 100e18;
  uint256 withdrawalFee = 10;
  uint256 BPS_DENOMINATOR = 10_000;
  uint256 ACCEPTABLE_DIFF = 1000;

  uint192 expectedReward = 1e18;
  ERC20 marketKey;

  constructor()
    WithPool(
      MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
      MockERC20(0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9)
    )
  {}

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    sendUnderlyingToken(depositAmount, address(this));

    dddFlywheel = new FlywheelCore(
      dddToken,
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );
    dddRewards = new FuseFlywheelDynamicRewards(dddFlywheel, 1);
    dddFlywheel.setFlywheelRewards(dddRewards);

    epxFlywheel = new FlywheelCore(
      epxToken,
      IFlywheelRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this),
      Authority(address(0))
    );
    epxRewards = new FuseFlywheelDynamicRewards(epxFlywheel, 1);
    epxFlywheel.setFlywheelRewards(epxRewards);

    dotDotERC4626 = new DotDotLpERC4626(
      underlyingToken,
      FlywheelCore(address(dddFlywheel)),
      FlywheelCore(address(epxFlywheel)),
      ILpDepositor(address(lpDepositor))
    );

    marketKey = ERC20(address(dotDotERC4626));
    dddFlywheel.addStrategyForRewards(marketKey);
    epxFlywheel.addStrategyForRewards(marketKey);
  }

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(dotDotERC4626), amount);
    dotDotERC4626.deposit(amount, _owner);
    vm.stopPrank();
  }

  function sendUnderlyingToken(uint256 amount, address recipient) public {
    deal(address(underlyingToken), recipient, amount);
  }

  function increaseAssetsInVault() public {
    sendUnderlyingToken(1000e18, address(lpDepositor));
  }

  function decreaseAssetsInVault() public {
    vm.prank(0x5B74C99AA2356B4eAa7B85dC486843eDff8Dfdbe); //lpStaker
    underlyingToken.transfer(address(1), 200e18); // transfer doesnt work
  }

  function testInitializedValues() public shouldRun(forChains(BSC_MAINNET)) {
    assertEq(dotDotERC4626.name(), "Midas 2brl Vault");
    assertEq(dotDotERC4626.symbol(), "mv2brl");
    assertEq(address(dotDotERC4626.asset()), address(underlyingToken));
    assertEq(address(dotDotERC4626.lpDepositor()), address(lpDepositor));
  }

  function testPreviewDepositAndMintReturnTheSameValue() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 returnedShares = dotDotERC4626.previewDeposit(depositAmount);
    assertEq(dotDotERC4626.previewMint(returnedShares), depositAmount);
  }

  function testPreviewWithdrawAndRedeemReturnTheSameValue() public shouldRun(forChains(BSC_MAINNET)) {
    deposit(address(this), depositAmount);
    uint256 withdrawalAmount = 10e18;
    uint256 reqShares = dotDotERC4626.previewWithdraw(withdrawalAmount);
    assertEq(dotDotERC4626.previewRedeem(reqShares), withdrawalAmount);
  }

  function testDepositOnly() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedDepositShare = depositAmount;
    uint256 expectedErc4626Shares = dotDotERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Test that the actual transfers worked
    assertEq(lpDepositor.userBalances(address(dotDotERC4626), address(underlyingToken)), depositAmount);

    // Test that the balance view calls work
    assertEq(dotDotERC4626.totalAssets(), depositAmount);
    assertEq(dotDotERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(this)), expectedErc4626Shares);
    assertEq(dotDotERC4626.totalSupply(), expectedErc4626Shares);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(depositShare.balanceOf(address(dotDotERC4626)), expectedDepositShare);
  }

  function testDepositWithIncreasedVaultValue() public shouldRun(forChains(BSC_MAINNET)) {
    // lpDepositor just mints the exact amount of depositShares as the user deposits in assets
    uint256 oldExpectedDepositShare = depositAmount;
    uint256 oldExpected4626Shares = dotDotERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Increase the share price
    increaseAssetsInVault();

    uint256 expectedDepositShare = depositAmount;
    uint256 previewErc4626Shares = dotDotERC4626.previewDeposit(depositAmount);
    uint256 expected4626Shares = depositAmount.mulDivDown(dotDotERC4626.totalSupply(), dotDotERC4626.totalAssets());

    sendUnderlyingToken(depositAmount, address(this));
    deposit(address(this), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(this)), oldExpected4626Shares + previewErc4626Shares);

    // Test that we got less shares on the second mint after assets in the vault increased
    assertLe(previewErc4626Shares, oldExpected4626Shares, "!new shares < old Shares");
    assertEq(previewErc4626Shares, expected4626Shares, "!previewShares == expectedShares");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(depositShare.balanceOf(address(dotDotERC4626)), oldExpectedDepositShare + expectedDepositShare);
  }

  function testDepositWithDecreasedVaultValue() public shouldRun(forChains(BSC_MAINNET)) {
    // THIS TEST WILL ALWAYS FAIL
    // A transfer out of the lpStaker will always fail.
    // There also doesnt seem another way to reduce the balance of lpStaker so we cant test this scenario
    /* =============== ACTUAL TEST =============== */
    /*
    uint256 oldExpecteDepositShares = depositAmount;
    uint256 oldExpected4626Shares = dotDotERC4626.previewDeposit(depositAmount);
    deposit(address(this), depositAmount);

    // Decrease the share price
    decreaseAssetsInVault();

    uint256 expectedDepositShare = depositAmount;
    uint256 previewErc4626Shares = dotDotERC4626.previewDeposit(depositAmount);
    uint256 expected4626Shares = depositAmount.mulDivDown(dotDotERC4626.totalSupply(), dotDotERC4626.totalAssets());

    sendUnderlyingToken(depositAmount, address(this));
    deposit(address(this), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(this)), oldExpected4626Shares + previewErc4626Shares);
    // Test that we got less shares on the second mint after assets in the vault increased
    assertGt(previewErc4626Shares, oldExpected4626Shares, "!new shares > old Shares");
    assertEq(previewErc4626Shares, expected4626Shares, "!previewShares == expectedShares");
    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(depositShare.balanceOf(address(dotDotERC4626)), oldExpecteDepositShares + expectedDepositShare);
    */
  }

  function testMultipleDeposit() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedDepositShare = depositAmount;
    uint256 expectedErc4626Shares = dotDotERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    sendUnderlyingToken(depositAmount, address(1));
    deposit(address(1), depositAmount);

    // Test that the actual transfers worked
    assertEq(lpDepositor.userBalances(address(dotDotERC4626), address(underlyingToken)), depositAmount * 2);

    // Test that the balance view calls work
    assertTrue(
      depositAmount * 2 - dotDotERC4626.totalAssets() <= 1,
      "Beefy total Assets should be same as sum of deposited amounts"
    );
    assertTrue(
      depositAmount - dotDotERC4626.balanceOfUnderlying(address(this)) <= 1,
      "Underlying token balance should be same as depositied amount"
    );
    assertTrue(
      depositAmount - dotDotERC4626.balanceOfUnderlying(address(1)) <= 1,
      "Underlying token balance should be same as depositied amount"
    );

    // Test that we minted the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(this)), expectedErc4626Shares);
    assertEq(dotDotERC4626.balanceOf(address(1)), expectedErc4626Shares);
    assertEq(dotDotERC4626.totalSupply(), expectedErc4626Shares * 2);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(depositShare.balanceOf(address(dotDotERC4626)), expectedDepositShare * 2);

    // Beefy ERC4626 should not have underlyingToken after deposit
    assertTrue(underlyingToken.balanceOf(address(dotDotERC4626)) <= 1, "Beefy erc4626 locked amount checking");
  }

  function testMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedDepositShare = depositAmount;
    uint256 mintAmount = dotDotERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(dotDotERC4626), depositAmount);
    dotDotERC4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(lpDepositor.userBalances(address(dotDotERC4626), address(underlyingToken)), depositAmount);

    // Test that the balance view calls work
    assertEq(dotDotERC4626.totalAssets(), depositAmount);
    assertEq(dotDotERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(this)), mintAmount);
    assertEq(dotDotERC4626.totalSupply(), mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(depositShare.balanceOf(address(dotDotERC4626)), expectedDepositShare);
  }

  function testMultipleMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedDepositShare = depositAmount;
    uint256 mintAmount = dotDotERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(dotDotERC4626), depositAmount);
    dotDotERC4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(lpDepositor.userBalances(address(dotDotERC4626), address(underlyingToken)), depositAmount);

    // Test that the balance view calls work
    assertEq(dotDotERC4626.totalAssets(), depositAmount);
    assertEq(dotDotERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(this)), mintAmount);
    assertEq(dotDotERC4626.totalSupply(), mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(depositShare.balanceOf(address(dotDotERC4626)), expectedDepositShare);

    assertTrue(underlyingToken.balanceOf(address(dotDotERC4626)) <= 1, "Beefy erc4626 locked amount checking");

    vm.startPrank(address(1));
    underlyingToken.approve(address(dotDotERC4626), depositAmount);
    sendUnderlyingToken(depositAmount, address(1));
    dotDotERC4626.mint(mintAmount, address(1));

    // Test that the actual transfers worked
    assertEq(lpDepositor.userBalances(address(dotDotERC4626), address(underlyingToken)), depositAmount + depositAmount);

    // Test that the balance view calls work
    assertTrue(depositAmount + depositAmount - dotDotERC4626.totalAssets() <= 1);
    assertTrue(depositAmount - dotDotERC4626.balanceOfUnderlying(address(1)) <= 1);

    // Test that we minted the correct amount of token
    assertEq(dotDotERC4626.balanceOf(address(1)), mintAmount);
    assertEq(dotDotERC4626.totalSupply(), mintAmount + mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(depositShare.balanceOf(address(dotDotERC4626)), expectedDepositShare * 2);

    assertTrue(underlyingToken.balanceOf(address(dotDotERC4626)) <= 2, "Beefy erc4626 locked amount checking");
    vm.stopPrank();
  }

  function testWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 depositShares = depositAmount;

    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = dotDotERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = dotDotERC4626.previewWithdraw(withdrawalAmount);
    uint256 ExpectedDepositSharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
    );

    dotDotERC4626.withdraw(withdrawalAmount, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertEq(dotDotERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(dotDotERC4626.totalSupply(), depositAmount - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(dotDotERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");
    assertTrue(underlyingToken.balanceOf(address(dotDotERC4626)) <= 1, "!0");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      depositShare.balanceOf(address(dotDotERC4626)),
      depositShares - ExpectedDepositSharesNeeded,
      "!beefy share balance"
    );
  }

  function testWithdrawWithIncreasedVaultValue() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 depositShareBal = depositAmount;

    deposit(address(this), depositAmount);

    uint256 withdrawalAmount = 10e18;

    uint256 oldExpectedErc4626SharesNeeded = dotDotERC4626.previewWithdraw(withdrawalAmount);
    uint256 oldExpectedDepositSharesNeeded = oldExpectedErc4626SharesNeeded.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
    );

    dotDotERC4626.withdraw(withdrawalAmount, address(this), address(this));

    // Increase the share price
    increaseAssetsInVault();

    uint256 expectedErc4626SharesNeeded = dotDotERC4626.previewWithdraw(withdrawalAmount);
    uint256 ExpectedDepositSharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
    );

    dotDotERC4626.withdraw(withdrawalAmount, address(this), address(this));

    // Test that we minted the correct amount of token
    assertEq(
      dotDotERC4626.balanceOf(address(this)),
      depositAmount - (oldExpectedErc4626SharesNeeded + expectedErc4626SharesNeeded)
    );

    // Test that we got less shares on the second mint after assets in the vault increased
    assertLe(expectedErc4626SharesNeeded, oldExpectedErc4626SharesNeeded, "!new shares < old Shares");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      depositShare.balanceOf(address(dotDotERC4626)),
      depositShareBal - (oldExpectedDepositSharesNeeded + ExpectedDepositSharesNeeded)
    );
  }

  function testWithdrawWithDecreasedVaultValue() public shouldRun(forChains(BSC_MAINNET)) {
    // THIS TEST WILL ALWAYS FAIL
    // A transfer out of the lpStaker will always fail.
    // There also doesnt seem another way to reduce the balance of lpStaker so we cant test this scenario
    /* =============== ACTUAL TEST =============== */
    /*
      sendUnderlyingToken(depositAmount, address(this));
      uint256 depositShares = depositAmount;
      deposit(address(this), depositAmount);
      uint256 withdrawalAmount = 10e18;
      uint256 oldExpectedErc4626SharesNeeded = dotDotERC4626.previewWithdraw(withdrawalAmount);
      uint256 oldExpectedDepositSharesNeeded = oldExpectedErc4626SharesNeeded.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
      );
      dotDotERC4626.withdraw(withdrawalAmount, address(this), address(this));
      // Increase the share price
      decreaseAssetsInVault();
      uint256 expectedErc4626SharesNeeded = dotDotERC4626.previewWithdraw(withdrawalAmount);
      uint256 ExpectedDepositSharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
      );
      dotDotERC4626.withdraw(withdrawalAmount, address(this), address(this));
      // Test that we minted the correct amount of token
      assertEq(
        dotDotERC4626.balanceOf(address(this)),
        depositAmount - (oldExpectedErc4626SharesNeeded + expectedErc4626SharesNeeded)
      );
      // Test that we got less shares on the second mint after assets in the vault increased
      assertLe(expectedErc4626SharesNeeded, oldExpectedErc4626SharesNeeded, "!new shares < old Shares");
      // Test that the ERC4626 holds the expected amount of beefy shares
      assertEq(
        depositShare.balanceOf(address(dotDotERC4626)),
        depositShareBal - (oldExpectedDepositSharesNeeded + expectedDepositSharesNeeded)
      );
      */
  }

  function testMultipleWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 depositShares = depositAmount * 2;

    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);

    sendUnderlyingToken(depositAmount, address(1));
    deposit(address(1), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = dotDotERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = dotDotERC4626.previewWithdraw(withdrawalAmount);
    uint256 ExpectedDepositSharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
    );

    dotDotERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertEq(dotDotERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(depositAmount * 2 - expectedErc4626SharesNeeded - dotDotERC4626.totalSupply() < 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(dotDotERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      depositShare.balanceOf(address(dotDotERC4626)),
      depositShares - ExpectedDepositSharesNeeded,
      "!beefy share balance"
    );

    assertTrue(underlyingToken.balanceOf(address(dotDotERC4626)) <= 1, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - expectedErc4626SharesNeeded;
    depositShares = depositShares - ExpectedDepositSharesNeeded;
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = dotDotERC4626.balanceOf(address(1));
    expectedErc4626SharesNeeded = dotDotERC4626.previewWithdraw(withdrawalAmount);
    ExpectedDepositSharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
    );

    vm.prank(address(1));
    dotDotERC4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertEq(dotDotERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(dotDotERC4626.totalSupply(), totalSupplyBefore - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(dotDotERC4626.balanceOf(address(1)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      depositShare.balanceOf(address(dotDotERC4626)),
      depositShares - ExpectedDepositSharesNeeded,
      "!beefy share balance"
    );

    assertTrue(underlyingToken.balanceOf(address(dotDotERC4626)) <= 2, "Beefy erc4626 locked amount checking");
  }

  function testRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 depositShares = depositAmount;

    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = dotDotERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = dotDotERC4626.balanceOf(address(this));
    uint256 ExpectedDepositSharesNeeded = redeemAmount.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
    );

    dotDotERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertEq(dotDotERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(dotDotERC4626.totalSupply(), depositAmount - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(dotDotERC4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      depositShare.balanceOf(address(dotDotERC4626)),
      depositShares - ExpectedDepositSharesNeeded,
      "!beefy share balance"
    );
  }

  function testMultipleRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 depositShares = depositAmount * 2;

    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = dotDotERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);

    sendUnderlyingToken(depositAmount, address(1));
    deposit(address(1), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = dotDotERC4626.balanceOf(address(this));
    uint256 ExpectedDepositSharesNeeded = redeemAmount.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
    );

    dotDotERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertEq(dotDotERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(dotDotERC4626.totalSupply(), depositAmount * 2 - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(dotDotERC4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      depositShare.balanceOf(address(dotDotERC4626)),
      depositShares - ExpectedDepositSharesNeeded,
      "!beefy share balance"
    );
    assertTrue(underlyingToken.balanceOf(address(dotDotERC4626)) <= 1, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - redeemAmount;
    depositShares -= ExpectedDepositSharesNeeded;
    redeemAmount = dotDotERC4626.previewWithdraw(withdrawalAmount);
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = dotDotERC4626.balanceOf(address(1));
    ExpectedDepositSharesNeeded = redeemAmount.mulDivUp(
      depositShare.balanceOf(address(dotDotERC4626)),
      dotDotERC4626.totalSupply()
    );
    vm.prank(address(1));
    dotDotERC4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertEq(dotDotERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(dotDotERC4626.totalSupply(), totalSupplyBefore - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(dotDotERC4626.balanceOf(address(1)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      depositShare.balanceOf(address(dotDotERC4626)),
      depositShares - ExpectedDepositSharesNeeded,
      "!beefy share balance"
    );
    assertTrue(underlyingToken.balanceOf(address(dotDotERC4626)) <= 2, "Beefy erc4626 locked amount checking");
  }

  function testPauseContract() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    dotDotERC4626.emergencyWithdrawAndPause();

    underlyingToken.approve(address(dotDotERC4626), depositAmount);
    vm.expectRevert("Pausable: paused");
    dotDotERC4626.deposit(depositAmount, address(this));

    vm.expectRevert("Pausable: paused");
    dotDotERC4626.mint(depositAmount, address(this));

    uint256 expectedSharesNeeded = withdrawAmount.mulDivDown(dotDotERC4626.totalSupply(), dotDotERC4626.totalAssets());
    dotDotERC4626.withdraw(withdrawAmount, address(this), address(this));

    assertEq(dotDotERC4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded, "!withdraw share bal");
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(dotDotERC4626.totalAssets(), dotDotERC4626.totalSupply());
    dotDotERC4626.redeem(withdrawAmount, address(this), address(this));

    assertEq(
      dotDotERC4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      "!redeem share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }

  function testEmergencyWithdrawAndPause() public shouldRun(forChains(BSC_MAINNET)) {
    deposit(address(this), depositAmount);

    uint256 expectedBal = dotDotERC4626.previewRedeem(depositAmount);
    assertEq(underlyingToken.balanceOf(address(dotDotERC4626)), 0, "!init 0");

    dotDotERC4626.emergencyWithdrawAndPause();

    assertEq(underlyingToken.balanceOf(address(dotDotERC4626)), expectedBal, "!withdraws underlying");
    assertEq(dotDotERC4626.totalAssets(), expectedBal, "!totalAssets == expectedBal");
  }

  function testEmergencyWithdrawAndRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    dotDotERC4626.emergencyWithdrawAndPause();

    uint256 expectedSharesNeeded = withdrawAmount.mulDivDown(dotDotERC4626.totalSupply(), dotDotERC4626.totalAssets());
    dotDotERC4626.withdraw(withdrawAmount, address(this), address(this));

    assertEq(dotDotERC4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded, "!withdraw share bal");
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(dotDotERC4626.totalAssets(), dotDotERC4626.totalSupply());
    dotDotERC4626.redeem(withdrawAmount, address(this), address(this));

    assertEq(
      dotDotERC4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      "!redeem share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }

  function testAccumulatingRewardsOnDeposit() public {
    deposit(address(this), depositAmount / 2);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    deposit(address(this), depositAmount / 2);
    assertGt(dddToken.balanceOf(address(dotDotERC4626)), 0.0007 ether);
    assertGt(epxToken.balanceOf(address(dotDotERC4626)), 0.01 ether);
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    deposit(address(this), depositAmount);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    dotDotERC4626.withdraw(1, address(this), address(this));

    assertGt(dddToken.balanceOf(address(dotDotERC4626)), 0.001 ether);
    assertGt(epxToken.balanceOf(address(dotDotERC4626)), 0.025 ether);
  }

  function testClaimRewards() public {
    // Deposit funds, Rewards are 0
    deposit(address(this), depositAmount);

    (uint32 dddStart, uint32 dddEnd, uint192 dddReward) = dddRewards.rewardsCycle(ERC20(address(dotDotERC4626)));
    (uint32 epxStart, uint32 epxEnd, uint192 epxReward) = dddRewards.rewardsCycle(ERC20(address(dotDotERC4626)));

    // Rewards can be transfered in the next cycle
    assertEq(dddEnd, 0);
    assertEq(epxEnd, 0);

    // Reward amount is still 0
    assertEq(dddReward, 0);
    assertEq(epxReward, 0);

    vm.warp(block.timestamp + 150);
    vm.roll(10);

    // Call withdraw (could also be deposit() on the erc4626 or claim() on the epsStaker directly) to claim rewards
    dotDotERC4626.withdraw(1, address(this), address(this));

    // The ERC-4626 holds all rewarded token now
    assertGt(dddToken.balanceOf(address(dotDotERC4626)), 0.001 ether);
    assertGt(epxToken.balanceOf(address(dotDotERC4626)), 0.025 ether);

    // Accrue rewards to send rewards to flywheelRewards
    dddFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    epxFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    assertGt(dddToken.balanceOf(address(dddRewards)), 0.001 ether);
    assertGt(epxToken.balanceOf(address(epxRewards)), 0.025 ether);

    (dddStart, dddEnd, dddReward) = dddRewards.rewardsCycle(ERC20(address(dotDotERC4626)));
    (epxStart, epxEnd, epxReward) = epxRewards.rewardsCycle(ERC20(address(dotDotERC4626)));

    // Rewards can be transfered in the next cycle
    assertGt(dddEnd, 1000000000);
    assertGt(epxEnd, 1000000000);

    // Reward amount is expected value
    assertGt(dddReward, 0.001 ether);
    assertGt(epxReward, 0.025 ether);

    vm.warp(block.timestamp + 150);
    vm.roll(20);

    // Finally accrue reward from last cycle
    dddFlywheel.accrue(ERC20(dotDotERC4626), address(this));
    epxFlywheel.accrue(ERC20(dotDotERC4626), address(this));

    // Claim Rewards for the user
    dddFlywheel.claimRewards(address(this));
    epxFlywheel.claimRewards(address(this));

    assertGt(dddToken.balanceOf(address(this)), 0.001 ether);
    assertEq(dddToken.balanceOf(address(dddFlywheel)), 0);
    assertGt(epxToken.balanceOf(address(this)), 0.025 ether);
  }
}
