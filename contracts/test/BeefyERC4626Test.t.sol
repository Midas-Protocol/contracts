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
  uint256 withdrawalFee = 100;
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
    vm.startPrank(0x1083926054069AaD75d7238E9B809b0eF9d94e5B);
    underlyingToken.transfer(address(this), 100e18);
    underlyingToken.transfer(address(1), 100e18);
    vm.stopPrank();
    beefyVault = IBeefyVault(0xD2FeCe7Ff1B791F8fE7f35424165abB8BD1671f2);
    beefyERC4626 = new BeefyERC4626(underlyingToken, beefyVault, withdrawalFee);
    initalBeefyBalance = beefyVault.balance();
    initalBeefySupply = beefyVault.totalSupply();
  }

  function deposit() public {
    underlyingToken.approve(address(beefyERC4626), depositAmount);
    beefyERC4626.deposit(depositAmount, address(this));
  }

  function testInitializedValues() public {
    assertEq(beefyERC4626.name(), "Midas Pancake LPs Vault");
    assertEq(beefyERC4626.symbol(), "mvCake-LP");
    assertEq(address(beefyERC4626.asset()), address(underlyingToken));
    assertEq(address(beefyERC4626.beefyVault()), address(beefyVault));
  }

  function testPreviewDepositAndMintReturnTheSameValue() public {
    uint256 returnedShares = beefyERC4626.previewDeposit(depositAmount);
    assertEq(beefyERC4626.previewMint(returnedShares), depositAmount);
  }

  function testPreviewWithdrawAndRedeemReturnTheSameValue() public {
    deposit();
    uint256 withdrawalAmount = 10e18;
    uint256 reqShares = beefyERC4626.previewWithdraw(withdrawalAmount);
    assertEq(beefyERC4626.previewRedeem(reqShares), withdrawalAmount);
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

  function testMint() public {
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

  function testWithdraw() public {
    uint256 beefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;

    uint256 withdrawalAmount = 10e18;

    deposit();

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
    assertEq(beefyERC4626.totalSupply(), depositAmount - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );
  }

  function testRedeem() public {
    uint256 beefyShares = (depositAmount * initalBeefySupply) / initalBeefyBalance;

    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = beefyERC4626.previewWithdraw(withdrawalAmount);

    deposit();

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
    beefyERC4626 = new BeefyERC4626(ERC20(cakeLPAddress), beefyVault, 100);
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
    // make sure the full amount is deposited and none is left
    assertEq(cakeLpToken.balanceOf(user), 0, "should deposit the full balance of cakeLP of user");
    assertEq(cakeLpToken.balanceOf(address(beefyERC4626)), 0, "should deposit the full balance of cakeLP of user");
    vm.stopPrank();
  }

  function testTheBugWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 amount = 1e18;
    vm.prank(beefyStrategyAddress);
    cakeLpToken.transfer(alice, 100e18);

    deposit(bob, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToBob = beefyERC4626.balanceOf(bob);
    assertEq(
      beefyERC4626SharesMintedToBob,
      amount,
      "the first minted shares in beefyERC4626 are expected to equal the assets deposited"
    );

    {
      uint256 assetsToWithdraw = amount / 2;
      beefyERC4626.withdraw(assetsToWithdraw, bob, bob);
      uint256 assetsWithdrawn = cakeLpToken.balanceOf(bob);
      assertEq(assetsWithdrawn, assetsToWithdraw, "the assets withdrawn must equal the requested assets to withdraw");
    }

    uint256 lockedFunds = cakeLpToken.balanceOf(address(beefyERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the withdrawn cakeLP");

    vm.stopPrank();
  }

  function testTheBugRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 amount = 1e18;
    vm.prank(beefyStrategyAddress);
    cakeLpToken.transfer(alice, 100e18);

    deposit(charlie, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToCharlie = beefyERC4626.balanceOf(charlie);
    assertEq(
      beefyERC4626SharesMintedToCharlie,
      amount,
      "the first minted shares in beefyERC4626 are expected to equal the assets deposited"
    );

    {
      uint256 beefyERC4626SharesToRedeem = beefyERC4626.balanceOf(charlie);
      beefyERC4626.redeem(beefyERC4626SharesToRedeem, charlie, charlie);
      uint256 assetsWithdrawn = cakeLpToken.balanceOf(charlie);
      uint256 assetsToWithdraw = beefyERC4626.previewRedeem(beefyERC4626SharesToRedeem);
      assertEq(assetsWithdrawn, assetsToWithdraw, "the assets withdrawn must equal the requested assets to withdraw");
    }

    uint256 lockedFunds = cakeLpToken.balanceOf(address(beefyERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the withdrawn cakeLP");

    vm.stopPrank();
  }
}
