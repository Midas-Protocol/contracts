// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { AlpacaERC4626, IAlpacaVault } from "../compound/strategies/AlpacaERC4626.sol";
import { MockVault } from "./mocks/alpaca/MockVault.sol";
import { IW_NATIVE } from "../utils/IW_NATIVE.sol";

contract AlpacaERC4626Test is BaseTest {
  AlpacaERC4626 alpacaERC4626;

  MockERC20 testToken;
  MockVault mockVault;

  uint256 depositAmount = 100e18;

  address alice = address(10);
  address bob = address(20);
  address charlie = address(30);

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    testToken = MockERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    mockVault = MockVault(0xd7D069493685A581d27824Fc46EdA46B7EfC0063);
    alpacaERC4626 = new AlpacaERC4626(
      testToken,
      IAlpacaVault(address(mockVault)),
      IW_NATIVE(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)
    );
  }

  function testInitializedValues() public shouldRun(forChains(BSC_MAINNET)) {
    assertEq(alpacaERC4626.name(), "Midas Wrapped BNB Vault");
    assertEq(alpacaERC4626.symbol(), "mvWBNB");
    assertEq(address(alpacaERC4626.asset()), address(testToken));
    assertEq(address(alpacaERC4626.alpacaVault()), address(mockVault));
  }

  function deposit(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of cakeLP of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(alpacaERC4626), amount);
    alpacaERC4626.deposit(amount, user);
    vm.stopPrank();
  }

  function mint(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of cakeLP of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(alpacaERC4626), amount);
    alpacaERC4626.mint(alpacaERC4626.previewDeposit(amount), user);
    vm.stopPrank();
  }

  function testTheBugWithdraw(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 1e18 && amount < 1e19);
    vm.prank(0x0eD7e52944161450477ee417DE9Cd3a859b14fD0);
    testToken.transferFrom(0x0eD7e52944161450477ee417DE9Cd3a859b14fD0, alice, 100e18);
    // testToken.mint(alice, 100e18);

    deposit(bob, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(bob), 0, "should deposit the full balance of cakeLP of user");
    assertEq(testToken.balanceOf(address(alpacaERC4626)), 0, "should deposit the full balance of cakeLP of user");

    // just testing if other users depositing would mess up the calcs
    mint(charlie, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToBob = alpacaERC4626.balanceOf(bob);
    assertEq(
      beefyERC4626SharesMintedToBob,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(bob);
      uint256 assetsToWithdraw = amount / 2;
      alpacaERC4626.withdraw(assetsToWithdraw, bob, bob);
      uint256 assetsWithdrawn = testToken.balanceOf(bob);
      assertTrue(
        diff(assetsWithdrawn, assetsToWithdraw) < 100,
        "the assets withdrawn must be almost equal to the requested assets to withdraw"
      );
      vm.stopPrank();
    }

    uint256 lockedFunds = testToken.balanceOf(address(alpacaERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the withdrawn cakeLP, no dust is acceptable");
  }

  function testTheBugRedeem(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 1e18 && amount < 1e19);
    vm.prank(0x0eD7e52944161450477ee417DE9Cd3a859b14fD0);
    testToken.transferFrom(0x0eD7e52944161450477ee417DE9Cd3a859b14fD0, alice, 100e18);

    deposit(charlie, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(charlie), 0, "should deposit the full balance of cakeLP of user");
    assertEq(testToken.balanceOf(address(alpacaERC4626)), 0, "should deposit the full balance of cakeLP of user");

    // just testing if other users depositing would mess up the calcs
    mint(bob, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToCharlie = alpacaERC4626.balanceOf(charlie);
    assertEq(
      beefyERC4626SharesMintedToCharlie,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(charlie);
      uint256 beefyERC4626SharesToRedeem = alpacaERC4626.balanceOf(charlie);
      alpacaERC4626.redeem(beefyERC4626SharesToRedeem, charlie, charlie);
      uint256 assetsRedeemed = testToken.balanceOf(charlie);
      uint256 assetsToRedeem = alpacaERC4626.previewRedeem(beefyERC4626SharesToRedeem);
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

    uint256 lockedFunds = testToken.balanceOf(address(alpacaERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the redeemed cakeLP, no dust is acceptable");
  }
}
