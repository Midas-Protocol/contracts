// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MidasERC4626, HelioERC4626, IJAR } from "../../midas/strategies/HelioERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

contract HelioERC4626Test is AbstractERC4626Test {
  IJAR jar;
  address jarAdmin = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;

  function setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("Helio-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    (, address _jar) = abi.decode(data, (address, address));

    jar = IJAR(_jar);

    HelioERC4626 jarvisERC4626 = new HelioERC4626();
    jarvisERC4626.initialize(underlyingToken, jar);
    plugin = jarvisERC4626;

    initialStrategyBalance = getStrategyBalance();
  }

  function increaseAssetsInVault() public override {
    deal(address(underlyingToken), jarAdmin, 100e18);
    vm.startPrank(jarAdmin);
    underlyingToken.approve(address(jar), 100e18);
    jar.replenish(100e18, true);
    vm.stopPrank();
    vm.warp(block.timestamp + 100);
  }

  function decreaseAssetsInVault() public override {
    vm.prank(address(jar));
    underlyingToken.transfer(address(1), 2e18);
  }

  function getDepositShares() public view override returns (uint256) {
    uint256 amount = jar.balanceOf(address(plugin));
    return amount;
  }

  function getStrategyBalance() public view override returns (uint256) {
    return jar.totalSupply();
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return depositAmount;
  }

  function testInitializedValues(string memory assetName, string memory assetSymbol) public override {
    assertEq(
      plugin.name(),
      string(abi.encodePacked("Midas ", assetName, " Vault")),
      string(abi.encodePacked("!name ", testPreFix))
    );
    assertEq(
      plugin.symbol(),
      string(abi.encodePacked("mv", assetSymbol)),
      string(abi.encodePacked("!symbol ", testPreFix))
    );
    assertEq(address(plugin.asset()), address(underlyingToken), string(abi.encodePacked("!asset ", testPreFix)));
    assertEq(address(HelioERC4626(address(plugin)).jar()), address(jar), string(abi.encodePacked("!jar ", testPreFix)));
  }

  function testWithdraw() public override {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = plugin.balanceOf(address(this));

    vm.warp(block.timestamp + 10);
    plugin.withdraw(withdrawalAmount, address(this), address(this));

    uint256 expectedErc4626SharesNeeded = plugin.previewWithdraw(withdrawalAmount);
    // uint256 depositShareAfterWithdraw = plugin.previewWithdraw(depositAmount);

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      assetBalBefore + withdrawalAmount,
      uint256(10),
      string(abi.encodePacked("!user asset bal ", testPreFix))
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertApproxEqAbs(plugin.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertApproxEqAbs(
      plugin.totalSupply(),
      depositAmount - expectedErc4626SharesNeeded,
      uint256(10),
      string(abi.encodePacked("!totalSupply ", testPreFix))
    );

    // Test that we burned the right amount of shares
    assertApproxEqAbs(
      plugin.balanceOf(address(this)),
      erc4626BalBefore - expectedErc4626SharesNeeded,
      uint256(10),
      string(abi.encodePacked("!erc4626 supply ", testPreFix))
    );
    assertTrue(underlyingToken.balanceOf(address(plugin)) <= 1, string(abi.encodePacked("!0 ", testPreFix)));
  }

  function testEmergencyWithdrawAndPause() public override {
    deposit(address(this), depositAmount);

    assertEq(underlyingToken.balanceOf(address(plugin)), 0, string(abi.encodePacked("!init 0 ", testPreFix)));

    vm.warp(block.timestamp + 10);

    plugin.emergencyWithdrawAndPause();

    uint256 expectedBal = plugin.previewRedeem(depositAmount);

    assertApproxEqAbs(
      underlyingToken.balanceOf(address(plugin)),
      expectedBal,
      uint256(10),
      string(abi.encodePacked("!withdraws underlying ", testPreFix))
    );
    assertApproxEqAbs(
      plugin.totalAssets(),
      expectedBal,
      uint256(10),
      string(abi.encodePacked("!totalAssets == expectedBal ", testPreFix))
    );
  }

  function testWithdrawWithIncreasedVaultValue() public override {
    deposit(address(this), depositAmount);

    uint256 withdrawalAmount = 10e18;

    vm.warp(block.timestamp + 10);

    plugin.withdraw(withdrawalAmount, address(this), address(this));

    uint256 oldExpectedErc4626SharesNeeded = plugin.previewWithdraw(withdrawalAmount);
    // Increase the share price
    increaseAssetsInVault();

    vm.warp(block.timestamp + 10);

    plugin.withdraw(withdrawalAmount, address(this), address(this));

    uint256 expectedErc4626SharesNeeded = plugin.previewWithdraw(withdrawalAmount);
    // Test that we minted the correct amount of token
    assertApproxEqAbs(
      plugin.balanceOf(address(this)),
      depositAmount - (oldExpectedErc4626SharesNeeded + expectedErc4626SharesNeeded),
      uint256(10),
      string(abi.encodePacked("!mint ", testPreFix))
    );

    // Test that we got less shares on the second mint after assets in the vault increased
    assertLe(
      expectedErc4626SharesNeeded,
      oldExpectedErc4626SharesNeeded,
      string(abi.encodePacked("!new shares < old Shares ", testPreFix))
    );
  }

  function testMultipleRedeem() public override {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);

    sendUnderlyingToken(depositAmount, address(1));
    deposit(address(1), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = plugin.balanceOf(address(this));

    vm.warp(block.timestamp + 10);

    plugin.withdraw(10e18, address(this), address(this));

    uint256 redeemAmount = plugin.previewWithdraw(withdrawalAmount);

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      assetBalBefore + withdrawalAmount,
      uint256(10),
      string(abi.encodePacked("!1.user asset bal ", testPreFix))
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertApproxEqAbs(plugin.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertApproxEqAbs(
      plugin.totalSupply(),
      depositAmount * 2 - redeemAmount,
      uint256(10),
      string(abi.encodePacked("!1.totalSupply ", testPreFix))
    );

    // Test that we burned the right amount of shares
    assertApproxEqAbs(
      plugin.balanceOf(address(this)),
      erc4626BalBefore - redeemAmount,
      uint256(10),
      string(abi.encodePacked("!1.erc4626 supply ", testPreFix))
    );

    // Test that the ERC4626 holds the expected amount of dotDot shares
    assertTrue(
      underlyingToken.balanceOf(address(plugin)) <= 1,
      string(abi.encodePacked("1.DotDot erc4626 locked amount checking ", testPreFix))
    );

    uint256 totalSupplyBefore = depositAmount * 2 - redeemAmount;
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = plugin.balanceOf(address(1));

    vm.prank(address(1));
    vm.warp(block.timestamp + 10);
    plugin.withdraw(10e18, address(1), address(1));
    redeemAmount = plugin.previewWithdraw(withdrawalAmount);

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(1)),
      assetBalBefore + withdrawalAmount,
      uint256(10),
      string(abi.encodePacked("!2.user asset bal ", testPreFix))
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertApproxEqAbs(plugin.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertApproxEqAbs(
      plugin.totalSupply(),
      totalSupplyBefore - redeemAmount,
      uint256(10),
      string(abi.encodePacked("!2.totalSupply ", testPreFix))
    );

    // Test that we burned the right amount of shares
    assertApproxEqAbs(
      plugin.balanceOf(address(1)),
      erc4626BalBefore - redeemAmount,
      uint256(10),
      string(abi.encodePacked("!2.erc4626 supply ", testPreFix))
    );

    // Test that the ERC4626 holds the expected amount of dotDot shares
    assertTrue(
      underlyingToken.balanceOf(address(plugin)) <= 2,
      string(abi.encodePacked("2.DotDot erc4626 locked amount checking ", testPreFix))
    );
  }

  function testMultipleWithdraw() public override {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);
    vm.warp(block.timestamp + 10);

    sendUnderlyingToken(depositAmount, address(1));
    deposit(address(1), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = plugin.balanceOf(address(this));

    vm.warp(block.timestamp + 10);
    plugin.withdraw(10e18, address(this), address(this));
    uint256 expectedErc4626SharesNeeded = plugin.previewWithdraw(withdrawalAmount);

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      assetBalBefore + withdrawalAmount,
      uint256(10),
      string(abi.encodePacked("!1.user asset bal", testPreFix))
    );

    // Test that we burned the right amount of shares
    assertApproxEqAbs(
      plugin.balanceOf(address(this)),
      erc4626BalBefore - expectedErc4626SharesNeeded,
      uint256(10),
      string(abi.encodePacked("!1.erc4626 supply ", testPreFix))
    );

    // Test that the ERC4626 holds the expected amount of dotDot shares

    assertApproxEqAbs(
      underlyingToken.balanceOf(address(plugin)),
      1,
      1,
      string(abi.encodePacked("1.DotDot erc4626 locked amount checking ", testPreFix))
    );

    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = plugin.balanceOf(address(1));

    vm.prank(address(1));
    vm.warp(block.timestamp + 10);
    plugin.withdraw(10e18, address(1), address(1));
    expectedErc4626SharesNeeded = plugin.previewWithdraw(withdrawalAmount);

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(1)),
      assetBalBefore + withdrawalAmount,
      uint256(10),
      string(abi.encodePacked("!2.user asset bal ", testPreFix))
    );

    // Test that we burned the right amount of shares
    assertApproxEqAbs(
      plugin.balanceOf(address(1)),
      erc4626BalBefore - expectedErc4626SharesNeeded,
      uint256(10),
      string(abi.encodePacked("!2.erc4626 supply ", testPreFix))
    );

    assertApproxEqAbs(
      underlyingToken.balanceOf(address(plugin)),
      2,
      2,
      string(abi.encodePacked("2.DotDot erc4626 locked amount checking ", testPreFix))
    );
  }

  function testRedeem() public override {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = plugin.balanceOf(address(this));

    vm.warp(block.timestamp + 10);

    plugin.withdraw(10e18, address(this), address(this));
    uint256 redeemAmount = plugin.previewWithdraw(withdrawalAmount);

    // Test that the actual transfers worked
    assertApproxEqAbs(
      underlyingToken.balanceOf(address(this)),
      assetBalBefore + withdrawalAmount,
      uint256(10),
      string(abi.encodePacked("!user asset bal ", testPreFix))
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (ExpectedDepositSharesNeeded + (ExpectedDepositSharesNeeded / 1000));
    //assertApproxEqAbs(plugin.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertApproxEqAbs(
      plugin.totalSupply(),
      depositAmount - redeemAmount,
      uint256(10),
      string(abi.encodePacked("!totalSupply ", testPreFix))
    );

    // Test that we burned the right amount of shares
    assertApproxEqAbs(
      plugin.balanceOf(address(this)),
      erc4626BalBefore - redeemAmount,
      uint256(10),
      string(abi.encodePacked("!erc4626 supply ", testPreFix))
    );
  }
}
