// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
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

  MockERC20 testToken;
  MockStrategy mockStrategy;
  MockVault mockVault;

  uint256 depositAmount = 100e18;

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
    setUpPool("beefy-test", false, 0.1e18, 1.1e18);
  }

  function testDeployCErc20PluginDelegate() public shouldRun(forChains(BSC_MAINNET)) {
    emit log_uint(underlyingToken.balanceOf(address(this)));
    mockStrategy = new MockStrategy(address(underlyingToken));
    mockVault = new MockVault(address(mockStrategy), "MockVault", "MV");
    beefyERC4626 = new BeefyERC4626(underlyingToken, IBeefyVault(address(mockVault)));

    deployCErc20PluginDelegate(ERC4626(address(underlyingToken)), 0.9e18);
    CToken[] memory allmarkets = comptroller.getAllMarkets();
    CErc20PluginDelegate cToken = CErc20PluginDelegate(address(allmarkets[allmarkets.length - 1]));

    cToken._setImplementationSafe(address(cErc20PluginDelegate), false, abi.encode(address(beefyERC4626)));
    assertEq(address(cToken.plugin()), address(beefyERC4626));

    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);

    uint256 balanceOfVault = underlyingToken.balanceOf(address(mockVault));
    uint256 cTokenBalance = cToken.balanceOf(address(this));

    cToken.mint(1000);
    cTokenBalance = cToken.balanceOf(address(this));
    assertEq(cToken.totalSupply(), 1000 * 5);
    uint256 erc4626Balance = beefyERC4626.balanceOf(address(cToken));
    assertEq(erc4626Balance, 1000);
    assertEq(cTokenBalance, 1000 * 5);
    uint256 underlyingBalance = underlyingToken.balanceOf(address(this));

    vm.startPrank(address(1));

    underlyingToken.approve(address(cToken), 1e36);
    cToken.mint(1000);
    balanceOfVault = underlyingToken.balanceOf(address(mockVault));
    cTokenBalance = cToken.balanceOf(address(1));
    assertEq(cTokenBalance, 1000 * 5);
    erc4626Balance = beefyERC4626.balanceOf(address(cToken));
    assertEq(erc4626Balance, 2000);
    assertEq(cToken.totalSupply(), 1000 * 5 + cTokenBalance);
    underlyingBalance = underlyingToken.balanceOf(address(1));

    vm.stopPrank();

    cToken.redeemUnderlying(1000);
    cTokenBalance = cToken.balanceOf(address(this));
    erc4626Balance = beefyERC4626.balanceOf(address(cToken));
    assertEq(erc4626Balance, 1000);
    underlyingBalance = underlyingToken.balanceOf(address(this));
    assertEq(underlyingBalance, 100e18);
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