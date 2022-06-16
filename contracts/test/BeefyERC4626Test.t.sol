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

contract BeefyERC4626Test is WithPool, BaseTest {
  BeefyERC4626 beefyERC4626;
  IBeefyVault beefyVault;
  address beefyStrategy = 0xEeBcd7E1f008C52fe5804B306832B7DD317e163D;

  uint256 depositAmount = 100e18;

  uint256 initalBeefyBalance;
  uint256 initalBeefySupply;

  constructor()
    WithPool(
      MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA),
      MockERC20(0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6)
    )
  {}

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    vm.startPrank(0x1083926054069AaD75d7238E9B809b0eF9d94e5B);
    underlyingToken.transfer(address(this), 100e18);
    underlyingToken.transfer(address(1), 100e18);
    vm.stopPrank();
    beefyVault = IBeefyVault(0xD2FeCe7Ff1B791F8fE7f35424165abB8BD1671f2);
    beefyERC4626 = new BeefyERC4626(underlyingToken, beefyVault, 100);
    initalBeefyBalance = beefyVault.balance();
    initalBeefySupply = beefyVault.totalSupply();
  }

  // function testInitializedValues() public {
  //   assertEq(beefyERC4626.name(), "Midas Pancake LPs Vault");
  //   assertEq(beefyERC4626.symbol(), "mvCake-LP");
  //   assertEq(address(beefyERC4626.asset()), address(underlyingToken));
  //   assertEq(address(beefyERC4626.beefyVault()), address(beefyVault));
  // }

  function deposit() public {
    underlyingToken.approve(address(beefyERC4626), depositAmount);
    beefyERC4626.deposit(depositAmount, address(this));
  }

  function testDeposit() public {
    uint256 expectedBeefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;
    uint256 expectedErc4626Shares = beefyERC4626.previewDeposit(depositAmount);

    deposit();

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

  function testWithdraw() public {
    uint256 beefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;

    deposit();

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beefyERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = beefyERC4626.previewWithdraw(10e18);
    uint256 expectedBeefySharesNeeded = (expectedErc4626SharesNeeded * beefyVault.balanceOf(address(this))) /
      beefyERC4626.totalSupply();

    beefyERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertEq(underlyingToken.balanceOf(address(this)), assetBalBefore + 10e18, "!user asset bal");

    // Test that the balance view calls work
    // assertEq(beefyERC4626.totalAssets(), depositAmount - expectedErc4626SharesNeeded, "!erc4626 asset bal");
    // assertEq(beefyERC4626.balanceOfUnderlying(address(this)), depositAmount - expectedErc4626SharesNeeded);
    // assertEq(beefyERC4626.totalSupply(), depositAmount - expectedErc4626SharesNeeded);

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    // assertEq(beefyVault.balanceOf(address(beefyERC4626)), beefyShares - expectedBeefySharesNeeded);
  }
}

contract BeefyERC4626UnitTest is BaseTest {
  BeefyERC4626 beefyERC4626;
  address cakeLPAddress = 0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6;
  address beefyStrategyAddress = 0x1083926054069AaD75d7238E9B809b0eF9d94e5B;
  address beefyVaultAddress = 0x94E85B8E050F3F281CB9597cc0144F1F7AF1fe9B;
  address alice = address(10);
  address bob = address(20);
  IBeefyVault beefyVault;
  ERC20 cakeLpToken;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    beefyVault = IBeefyVault(beefyVaultAddress);
    beefyERC4626 = new BeefyERC4626(ERC20(cakeLPAddress), beefyVault);
    cakeLpToken = ERC20(cakeLPAddress);
  }

  function testTheBug() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 amount = 1e18;
    vm.prank(beefyStrategyAddress);
    cakeLpToken.transfer(alice, 100e18);

    // transfer to bob exactly amount
    vm.prank(alice);
    cakeLpToken.transfer(bob, amount);
    assertEq(cakeLpToken.balanceOf(bob), amount, "the full balance of cakeLP of bob should equal amount");

    // deposit the full amount to the plugin as bob, check the result
    vm.startPrank(bob);
    cakeLpToken.approve(address(beefyERC4626), amount);
    beefyERC4626.deposit(amount, bob);
    // make sure the full amount is deposited and none is left
    assertEq(cakeLpToken.balanceOf(bob), 0, "should deposit the full balance of cakeLP of bob");

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToBob = beefyERC4626.balanceOf(bob);
    assertEq(beefyERC4626SharesMintedToBob, amount, "the first minted shares in beefyERC4626 are expected to equal the assets deposited");

    uint256 beefyVaultSharesMintedToPlugin = beefyVault.balanceOf(address(beefyERC4626));

    {
      emit log_uint(amount);
      emit log_uint(beefyERC4626SharesMintedToBob);
      emit log_uint(beefyVaultSharesMintedToPlugin);
    }

    uint256 assetsToWithdraw = amount / 2;
    uint256 beefyVaultSharesToWithdraw = beefyERC4626.previewWithdraw(assetsToWithdraw);
    assertEq(beefyVaultSharesToWithdraw, beefyVaultSharesMintedToPlugin / 2, "previewWithdraw must return the shares of the beefy vault to redeem");

    uint256 sharesToRedeem = beefyERC4626SharesMintedToBob / 2;
    uint256 assetsToWithdrawFromBeefyVault = beefyERC4626.previewRedeem(sharesToRedeem);
    assertEq(assetsToWithdrawFromBeefyVault, assetsToWithdraw, "expected assets to withdraw should equal half of the assets owned in the beefy vault");

    beefyERC4626.withdraw(assetsToWithdraw, bob, bob);
    uint256 assetsWithdrawn = cakeLpToken.balanceOf(bob);

    {
      emit log_uint(assetsToWithdraw);
      emit log_uint(assetsWithdrawn);
    }
    assertEq(assetsWithdrawn, assetsToWithdraw, "the assets withdrawn must equal the requested assets to withdraw");

    vm.stopPrank();
  }
}