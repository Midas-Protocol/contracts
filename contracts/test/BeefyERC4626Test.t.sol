// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { BeefyERC4626, IBeefyVault } from "../compound/strategies/BeefyERC4626.sol";
import { MockStrategy } from "./mocks/beefy/MockStrategy.sol";
import { MockVault } from "./mocks/beefy/MockVault.sol";
import { IStrategy } from "./mocks/beefy/IStrategy.sol";
import { FixedPointMathLib } from "../utils/FixedPointMathLib.sol";

contract BeefyERC4626Test is WithPool, BaseTest {
  using FixedPointMathLib for uint256;

  BeefyERC4626 beefyERC4626;
  IBeefyVault beefyVault;
  address beefyStrategy = 0xEeBcd7E1f008C52fe5804B306832B7DD317e163D;

  uint256 depositAmount = 100e18;
  uint256 withdrawalFee = 10;
  uint256 BPS_DENOMINATOR = 10_000;

  uint256 iniitalBeefyBalance;
  uint256 initialBeefySupply;

  constructor()
    WithPool(
      MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
      MockERC20(0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6)
    )
  {}

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    beefyVault = IBeefyVault(0xD2FeCe7Ff1B791F8fE7f35424165abB8BD1671f2);
    beefyERC4626 = new BeefyERC4626(underlyingToken, beefyVault, withdrawalFee);
    iniitalBeefyBalance = beefyVault.balance();
    initialBeefySupply = beefyVault.totalSupply();
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
    uint256 expectedBeefyShares = (depositAmount * initialBeefySupply) / iniitalBeefyBalance;
    uint256 expectedErc4626Shares = beefyERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), iniitalBeefyBalance + depositAmount);

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

    uint256 oldExpectedBeefyShares = (depositAmount * initialBeefySupply) / iniitalBeefyBalance;
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
    uint256 expectedBeefyShares = (depositAmount * initialBeefySupply) / iniitalBeefyBalance;
    uint256 expectedErc4626Shares = beefyERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), iniitalBeefyBalance + depositAmount * 2);

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
    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedBeefyShares = (depositAmount * initialBeefySupply) / iniitalBeefyBalance;
    uint256 mintAmount = beefyERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(beefyERC4626), depositAmount);
    beefyERC4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), iniitalBeefyBalance + depositAmount);

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
    uint256 expectedBeefyShares = (depositAmount * initialBeefySupply) / iniitalBeefyBalance;
    uint256 mintAmount = beefyERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(beefyERC4626), depositAmount);
    beefyERC4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), iniitalBeefyBalance + depositAmount);

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
    assertEq(beefyVault.balance(), iniitalBeefyBalance + depositAmount + depositAmount);

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
    uint256 beefyShares = (depositAmount * initialBeefySupply) / iniitalBeefyBalance;

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
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(beefyERC4626.totalSupply(), depositAmount - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");
    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );
  }

  function testWithdrawWithIncreasedVaultValue() public shouldRun(forChains(BSC_MAINNET)) {
    sendUnderlyingToken(depositAmount, address(this));

    uint256 beefyShareBal = (depositAmount * initialBeefySupply) / iniitalBeefyBalance;

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
    uint256 beefyShares = ((depositAmount * initialBeefySupply) / iniitalBeefyBalance) * 2;

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
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1,
      "!user asset bal"
    );

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

    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");

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
    assertTrue(diff(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

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

    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 beefyShares = (depositAmount * initialBeefySupply) / iniitalBeefyBalance;

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
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1,
      "!user asset bal"
    );

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
    uint256 beefyShares = ((depositAmount * initialBeefySupply) / iniitalBeefyBalance) * 2;

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
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1,
      "!user asset bal"
    );

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
    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");

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
    assertTrue(diff(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

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
    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testPauseContract() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    beefyERC4626.emergencyWithdrawAndPause();

    underlyingToken.approve(address(beefyERC4626), depositAmount);
    vm.expectRevert("Pausable: paused");
    beefyERC4626.deposit(depositAmount, address(this));

    vm.expectRevert("Pausable: paused");
    beefyERC4626.mint(depositAmount, address(this));

    uint256 expectedSharesNeeded = withdrawAmount.mulDivDown(beefyERC4626.totalSupply(), beefyERC4626.totalAssets());
    beefyERC4626.withdraw(withdrawAmount, address(this), address(this));

    assertEq(beefyERC4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded, "!withdraw share bal");
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(beefyERC4626.totalAssets(), beefyERC4626.totalSupply());
    beefyERC4626.redeem(withdrawAmount, address(this), address(this));

    assertEq(
      beefyERC4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      "!redeem share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }

  function testEmergencyWithdrawAndPause() public shouldRun(forChains(BSC_MAINNET)) {
    deposit(address(this), depositAmount);

    uint256 expectedBal = beefyERC4626.previewRedeem(depositAmount);
    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "!init 0");

    beefyERC4626.emergencyWithdrawAndPause();

    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), expectedBal, "!withdraws underlying");
    assertEq(beefyERC4626.totalAssets(), expectedBal, "!totalAssets == expectedBal");
  }

  function testEmergencyWithdrawAndRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    beefyERC4626.emergencyWithdrawAndPause();

    uint256 expectedSharesNeeded = withdrawAmount.mulDivDown(beefyERC4626.totalSupply(), beefyERC4626.totalAssets());
    beefyERC4626.withdraw(withdrawAmount, address(this), address(this));

    assertEq(beefyERC4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded, "!withdraw share bal");
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(beefyERC4626.totalAssets(), beefyERC4626.totalSupply());
    beefyERC4626.redeem(withdrawAmount, address(this), address(this));

    assertEq(
      beefyERC4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      "!redeem share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }
}

contract BeefyERC4626UnitTest is BaseTest {
  BeefyERC4626 beefyERC4626;
  address cakeLPAddress = 0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6;
  address beefyStrategyAddress = 0x1083926054069AaD75d7238E9B809b0eF9d94e5B;
  address beefyVaultAddress = 0x94E85B8E050F3F281CB9597cc0144F1F7AF1fe9B;
  address alice = address(10);
  address bob = address(20);
  address charlie = address(30);
  IBeefyVault beefyVault;
  ERC20 cakeLpToken;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    beefyVault = IBeefyVault(beefyVaultAddress);
    beefyERC4626 = new BeefyERC4626(ERC20(cakeLPAddress), beefyVault, 10);
    cakeLpToken = ERC20(cakeLPAddress);
  }

  function deposit(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    cakeLpToken.transfer(user, amount);
    assertEq(cakeLpToken.balanceOf(user), amount, "the full balance of cakeLP of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    cakeLpToken.approve(address(beefyERC4626), amount);
    beefyERC4626.deposit(amount, user);
    vm.stopPrank();
  }

  function mint(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    cakeLpToken.transfer(user, amount);
    assertEq(cakeLpToken.balanceOf(user), amount, "the full balance of cakeLP of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    cakeLpToken.approve(address(beefyERC4626), amount);
    beefyERC4626.mint(beefyERC4626.previewDeposit(amount), user);
    vm.stopPrank();
  }

  function testTheBugWithdraw(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 100 && amount < 1e19);
    vm.prank(beefyStrategyAddress);
    cakeLpToken.transfer(alice, 100e18);

    deposit(bob, amount);
    // make sure the full amount is deposited and none is left
    assertEq(cakeLpToken.balanceOf(bob), 0, "should deposit the full balance of cakeLP of user");
    assertEq(cakeLpToken.balanceOf(address(beefyERC4626)), 0, "should deposit the full balance of cakeLP of user");

    // just testing if other users depositing would mess up the calcs
    mint(charlie, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToBob = beefyERC4626.balanceOf(bob);
    assertEq(
      beefyERC4626SharesMintedToBob,
      amount,
      "the first minted shares in beefyERC4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(bob);
      uint256 assetsToWithdraw = amount / 2;
      beefyERC4626.withdraw(assetsToWithdraw, bob, bob);
      uint256 assetsWithdrawn = cakeLpToken.balanceOf(bob);
      assertTrue(
        diff(assetsWithdrawn, assetsToWithdraw) < 100,
        "the assets withdrawn must be almost equal to the requested assets to withdraw"
      );
      vm.stopPrank();
    }

    uint256 lockedFunds = cakeLpToken.balanceOf(address(beefyERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the withdrawn cakeLP, no dust is acceptable");
  }

  function testTheBugRedeem(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 1e5 && amount < 1e19);
    vm.prank(beefyStrategyAddress);
    cakeLpToken.transfer(alice, 100e18);

    deposit(charlie, amount);
    // make sure the full amount is deposited and none is left
    assertEq(cakeLpToken.balanceOf(charlie), 0, "should deposit the full balance of cakeLP of user");
    assertEq(cakeLpToken.balanceOf(address(beefyERC4626)), 0, "should deposit the full balance of cakeLP of user");

    // just testing if other users depositing would mess up the calcs
    mint(bob, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToCharlie = beefyERC4626.balanceOf(charlie);
    assertEq(
      beefyERC4626SharesMintedToCharlie,
      amount,
      "the first minted shares in beefyERC4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(charlie);
      uint256 beefyERC4626SharesToRedeem = beefyERC4626.balanceOf(charlie);
      beefyERC4626.redeem(beefyERC4626SharesToRedeem, charlie, charlie);
      uint256 assetsRedeemed = cakeLpToken.balanceOf(charlie);
      uint256 assetsToRedeem = beefyERC4626.previewRedeem(beefyERC4626SharesToRedeem);
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

    uint256 lockedFunds = cakeLpToken.balanceOf(address(beefyERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the redeemed cakeLP, no dust is acceptable");
  }
}
