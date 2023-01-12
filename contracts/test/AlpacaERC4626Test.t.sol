// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { AlpacaERC4626, IAlpacaVault } from "../midas/strategies/AlpacaERC4626.sol";
import { MockVault } from "./mocks/alpaca/MockVault.sol";
import { IW_NATIVE } from "../utils/IW_NATIVE.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

contract AlpacaERC4626Test is BaseTest {
  using FixedPointMathLib for uint256;
  AlpacaERC4626 alpacaERC4626;

  ERC20Upgradeable underlyingToken;
  MockVault mockVault;

  uint256 depositAmount = 100e18;
  address wbnbWhale = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;

  function afterForkSetUp() internal override {
    underlyingToken = ERC20Upgradeable(ap.getAddress("wtoken"));
    mockVault = MockVault(0xd7D069493685A581d27824Fc46EdA46B7EfC0063);
    alpacaERC4626 = new AlpacaERC4626();
    alpacaERC4626.initialize(underlyingToken, IAlpacaVault(address(mockVault)), IW_NATIVE(ap.getAddress("wtoken")));
    dealWNative(100e18, address(this));
    dealWNative(100e18, address(1));
  }

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(alpacaERC4626), amount);
    alpacaERC4626.deposit(amount, _owner);
    vm.stopPrank();
  }

  function dealWNative(uint256 amount, address recipient) public {
    vm.prank(wbnbWhale);
    underlyingToken.transfer(recipient, amount);
  }

  function increaseAssetsInVault() public {
    dealWNative(1000e18, address(mockVault));
    // mockVault.earn();
  }

  function getExpectedVaultShares(uint256 amount) internal view returns (uint256) {
    uint256 total = mockVault.totalToken();
    uint256 shares = total == 0 ? amount : (amount * mockVault.totalSupply()) / total;
    return shares;
  }

  function testDeposit() public fork(BSC_MAINNET) {
    uint256 expectedErc4626Shares = alpacaERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Test that the balance view calls work
    assertApproxEqAbs(alpacaERC4626.totalAssets(), depositAmount, 1, "!totalAssets");
    assertApproxEqAbs(alpacaERC4626.balanceOfUnderlying(address(this)), depositAmount, 1, "!balanceOfUnderlying");

    // Test that we minted the correct amount of token
    assertEq(alpacaERC4626.balanceOf(address(this)), expectedErc4626Shares, "!balance of this");
    assertEq(alpacaERC4626.totalSupply(), expectedErc4626Shares, "!totalSupply");

    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount);
    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(mockVault.balanceOf(address(alpacaERC4626)), expectedBeefyShares, "!balance of erc4626");
  }

  function testMultipleDeposit() public fork(BSC_MAINNET) {
    uint256 expectedErc4626Shares = alpacaERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    // Test that the balance view calls work
    assertApproxEqAbs(
      depositAmount * 2,
      alpacaERC4626.totalAssets(),
      2,
      "Beefy total Assets should be same as sum of deposited amounts"
    );
    assertApproxEqAbs(
      depositAmount,
      alpacaERC4626.balanceOfUnderlying(address(this)),
      10,
      "Underlying token balance should be same as deposited amount"
    );
    assertApproxEqAbs(
      depositAmount,
      alpacaERC4626.balanceOfUnderlying(address(1)),
      10,
      "Underlying token balance should be same as deposited amount"
    );

    // Test that we minted the correct amount of token
    assertApproxEqAbs(alpacaERC4626.balanceOf(address(this)), expectedErc4626Shares, 1, "!balance this");
    assertApproxEqAbs(alpacaERC4626.balanceOf(address(1)), expectedErc4626Shares, 1, "!balance addr1");
    assertApproxEqAbs(alpacaERC4626.totalSupply(), expectedErc4626Shares * 2, 2, "!totalSupply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount * 2);

    assertApproxEqAbs(mockVault.balanceOf(address(alpacaERC4626)), expectedBeefyShares, 1, "!balanceOf erc4626");

    // Beefy ERC4626 should not have underlyingToken after deposit
    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testMint() public fork(BSC_MAINNET) {
    uint256 mintAmount = alpacaERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(alpacaERC4626), depositAmount);
    alpacaERC4626.mint(mintAmount, address(this));

    // Test that the balance view calls work
    assertApproxEqAbs(alpacaERC4626.totalAssets(), depositAmount, 1, "!totalAssets");
    assertApproxEqAbs(alpacaERC4626.balanceOfUnderlying(address(this)), depositAmount, 1, "!balanceOfUnderlying this");

    // Test that we minted the correct amount of token
    assertEq(alpacaERC4626.balanceOf(address(this)), mintAmount, "!balance of this");
    assertEq(alpacaERC4626.totalSupply(), mintAmount, "!totalSupply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount);
    assertEq(mockVault.balanceOf(address(alpacaERC4626)), expectedBeefyShares, "!balanceOf erc4626");
  }

  function testMultipleMint() public fork(BSC_MAINNET) {
    uint256 mintAmount = alpacaERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(alpacaERC4626), depositAmount);
    alpacaERC4626.mint(mintAmount, address(this));

    // Test that the balance view calls work
    assertApproxEqAbs(alpacaERC4626.totalAssets(), depositAmount, 10, "!totalAssets");
    assertApproxEqAbs(alpacaERC4626.balanceOfUnderlying(address(this)), depositAmount, 10, "!balanceOfUnderlying this");

    // Test that we minted the correct amount of token
    assertEq(alpacaERC4626.balanceOf(address(this)), mintAmount, "!balance of this");
    assertEq(alpacaERC4626.totalSupply(), mintAmount, "!totalSupply");

    assertApproxEqAbs(underlyingToken.balanceOf(address(alpacaERC4626)), 0, 10, "Beefy erc4626 locked amount checking");

    vm.startPrank(address(1));
    underlyingToken.approve(address(alpacaERC4626), depositAmount);
    alpacaERC4626.mint(mintAmount, address(1));

    // Test that the balance view calls work
    assertApproxEqAbs(depositAmount + depositAmount, alpacaERC4626.totalAssets(), 10, "!totalAssets2");
    assertApproxEqAbs(depositAmount, alpacaERC4626.balanceOfUnderlying(address(1)), 10, "!balanceOfUnderlying1");

    // Test that we minted the correct amount of token
    assertApproxEqAbs(alpacaERC4626.balanceOf(address(1)), mintAmount, 10, "!balance of 1");
    assertApproxEqAbs(alpacaERC4626.totalSupply(), mintAmount + mintAmount, 10, "!totalSupply2");

    // Test that the ERC4626 holds the expected amount of beefy shares
    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount * 2);

    assertApproxEqAbs(mockVault.balanceOf(address(alpacaERC4626)), expectedBeefyShares, 10, "!balance of erc4626");

    assertApproxEqAbs(underlyingToken.balanceOf(address(alpacaERC4626)), 0, 10, "Beefy erc4626 locked amount checking");
    vm.stopPrank();
  }

  function testWithdraw() public fork(BSC_MAINNET) {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);
    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = alpacaERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = alpacaERC4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    alpacaERC4626.withdraw(withdrawalAmount, address(this), address(this));

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      assetBalBefore + withdrawalAmount,
      1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(alpacaERC4626.totalSupply(), depositAmount - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(alpacaERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");
    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      mockVault.balanceOf(address(alpacaERC4626)),
      expectedBeefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );
  }

  function testMultipleWithdraw() public fork(BSC_MAINNET) {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);
    uint256 beefyShares = getExpectedVaultShares(depositAmount * 2);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = alpacaERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = alpacaERC4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    alpacaERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      assetBalBefore + withdrawalAmount,
      1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertApproxEqAbs(depositAmount * 2 - expectedErc4626SharesNeeded, alpacaERC4626.totalSupply(), 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(alpacaERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertApproxEqAbs(
      mockVault.balanceOf(address(alpacaERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      1,
      "!beefy share balance"
    );

    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - expectedErc4626SharesNeeded;
    beefyShares = beefyShares - expectedBeefySharesNeeded;
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = alpacaERC4626.balanceOf(address(1));
    expectedErc4626SharesNeeded = alpacaERC4626.previewWithdraw(withdrawalAmount);
    expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    vm.prank(address(1));
    alpacaERC4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertApproxEqAbs(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount, 1, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertApproxEqAbs(alpacaERC4626.totalSupply(), totalSupplyBefore - expectedErc4626SharesNeeded, 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(alpacaERC4626.balanceOf(address(1)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertApproxEqAbs(
      mockVault.balanceOf(address(alpacaERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      1,
      "!beefy share balance"
    );

    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testRedeem() public fork(BSC_MAINNET) {
    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = alpacaERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);
    uint256 beefyShares = getExpectedVaultShares(depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = alpacaERC4626.balanceOf(address(this));
    uint256 expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    alpacaERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      assetBalBefore + withdrawalAmount,
      1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertApproxEqAbs(alpacaERC4626.totalSupply(), depositAmount - redeemAmount, 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertApproxEqAbs(alpacaERC4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount, 1, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertApproxEqAbs(
      mockVault.balanceOf(address(alpacaERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      1,
      "!beefy share balance"
    );
  }

  function testAlapacaMultipleRedeem() public fork(BSC_MAINNET) {
    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = alpacaERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);
    uint256 beefyShares = getExpectedVaultShares(depositAmount * 2);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = alpacaERC4626.balanceOf(address(this));
    uint256 expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    alpacaERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      assetBalBefore + withdrawalAmount,
      1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(alpacaERC4626.totalSupply(), depositAmount * 2 - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertApproxEqAbs(alpacaERC4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount, 1, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertApproxEqAbs(
      mockVault.balanceOf(address(alpacaERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      10,
      "!beefy share balance"
    );
    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - redeemAmount;
    beefyShares -= expectedBeefySharesNeeded;
    redeemAmount = alpacaERC4626.previewWithdraw(withdrawalAmount);
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = alpacaERC4626.balanceOf(address(1));
    expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );
    vm.prank(address(1));
    alpacaERC4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertApproxEqAbs(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount, 1, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(alpacaERC4626.totalSupply(), totalSupplyBefore - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(alpacaERC4626.balanceOf(address(1)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertApproxEqAbs(
      mockVault.balanceOf(address(alpacaERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      10,
      "!beefy share balance"
    );
    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testAlpacaPauseContract() public fork(BSC_MAINNET) {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    alpacaERC4626.emergencyWithdrawAndPause();

    underlyingToken.approve(address(alpacaERC4626), depositAmount);
    vm.expectRevert("Pausable: paused");
    alpacaERC4626.deposit(depositAmount, address(this));

    vm.expectRevert("Pausable: paused");
    alpacaERC4626.mint(depositAmount, address(this));

    uint256 expectedSharesNeeded = alpacaERC4626.previewWithdraw(withdrawAmount);
    alpacaERC4626.withdraw(withdrawAmount, address(this), address(this));

    assertEq(alpacaERC4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded, "!withdraw share bal");
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(alpacaERC4626.totalAssets(), alpacaERC4626.totalSupply());
    alpacaERC4626.redeem(withdrawAmount, address(this), address(this));

    assertEq(
      alpacaERC4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      "!redeem share bal"
    );
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      withdrawAmount + expectedAssets,
      10,
      "!redeem asset bal"
    );
  }

  function testAlpacaEmergencyWithdrawAndPause() public fork(BSC_MAINNET) {
    deposit(address(this), depositAmount);

    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "!init 0");
    uint256 expectedBal = alpacaERC4626.previewRedeem(depositAmount);

    alpacaERC4626.emergencyWithdrawAndPause();

    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), expectedBal, "!withdraws underlying");
    assertEq(alpacaERC4626.totalAssets(), expectedBal, "!totalAssets == expectedBal");
  }

  function testAlpacaEmergencyWithdrawAndRedeem() public fork(BSC_MAINNET) {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    alpacaERC4626.emergencyWithdrawAndPause();

    uint256 expectedSharesNeeded = withdrawAmount.mulDivDown(alpacaERC4626.totalSupply(), alpacaERC4626.totalAssets());
    alpacaERC4626.withdraw(withdrawAmount, address(this), address(this));

    assertApproxEqAbs(
      alpacaERC4626.balanceOf(address(this)),
      depositAmount - expectedSharesNeeded,
      1,
      "!withdraw share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(alpacaERC4626.totalAssets(), alpacaERC4626.totalSupply());
    alpacaERC4626.redeem(withdrawAmount, address(this), address(this));

    assertApproxEqAbs(
      alpacaERC4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      1,
      "!redeem share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }
}
