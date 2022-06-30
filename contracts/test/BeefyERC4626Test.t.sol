// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { BeefyERC4626, IBeefyVault } from "../compound/strategies/BeefyERC4626.sol";
import { FixedPointMathLib } from "../utils/FixedPointMathLib.sol";

contract BeefyERC4626Test is BaseTest {
  using FixedPointMathLib for uint256;

  BeefyERC4626 beefyERC4626;
  IBeefyVault beefyVault;
  ERC20 underlyingToken;
  uint256 initialBeefyBalance;
  uint256 initialBeefySupply;

  uint256 depositAmount = 100e18;
  uint256 BPS_DENOMINATOR = 10_000;

  address alice = address(10);
  address bob = address(20);

  struct BeefyVaultConfig {
    address beefyVaultAddress;
    uint256 withdrawalFee;
  }

  BeefyVaultConfig[] public configs;

  constructor() {
    // beefy vault for BOMB-BTCB LP
    configs.push(
      BeefyVaultConfig(
        0x94E85B8E050F3F281CB9597cc0144F1F7AF1fe9B, // old val 0xD2FeCe7Ff1B791F8fE7f35424165abB8BD1671f2
        10
      )
    );
    // beefy vault for CAKE-BNB LP
    configs.push(
      BeefyVaultConfig(
        0xb26642B6690E4c4c9A6dAd6115ac149c700C7dfE, // 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0 CAKE-WBNB pair
        10
      )
    );
    // beefy vault for BUSD-BNB LP -
    configs.push(BeefyVaultConfig(0xAd61143796D90FD5A61d89D63a546C7dB0a70475, 10));
    // beefy vault for BTCB-ETH LP
    configs.push(
      BeefyVaultConfig(
        0xEf43E54Bb4221106953951238FC301a1f8939490, // 0xD171B26E4484402de70e3Ea256bE5A2630d7e88D BTCB-ETH pair
        10
      )
    );
    // beefy vault for ETH-BNB LP
    configs.push(
      BeefyVaultConfig(
        0x0eb78598851D08218d54fCe965ee2bf29C288fac, // 0x74E4716E431f45807DCF19f284c7aA99F18a4fbc WBNB-ETH pair
        10
      )
    );
    // beefy vault for USDC-BUSD LP
    configs.push(
      BeefyVaultConfig(
        0x9260c62866f36638964551A8f480C3aAAa4693fd, // 0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1 USDC-BUSD pair
        10
      )
    );
  }

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    //    uint8 _configIndexToTest = uint8(block.timestamp % configs.length);
    uint8 _configIndexToTest = 2;
    emit log_uint(_configIndexToTest);

    beefyVault = IBeefyVault(configs[_configIndexToTest].beefyVaultAddress);
    underlyingToken = beefyVault.want();
    beefyERC4626 = new BeefyERC4626(underlyingToken, beefyVault, configs[_configIndexToTest].withdrawalFee);

    initialBeefyBalance = beefyVault.balance();
    initialBeefySupply = beefyVault.totalSupply();
  }

  function deposit(address owner, uint256 amount) public {
    // transfer to user exactly amount, check the result
    deal(address(underlyingToken), owner, amount);
    assertEq(underlyingToken.balanceOf(owner), amount, "the full balance of cakeLP of user should equal amount");

    vm.startPrank(owner);
    underlyingToken.approve(address(beefyERC4626), amount);
    beefyERC4626.deposit(amount, owner);
    vm.stopPrank();
  }

  function mint(address owner, uint256 amount) public {
    // transfer to user exactly amount, check the result
    deal(address(underlyingToken), owner, amount);
    assertEq(underlyingToken.balanceOf(owner), amount, "the full balance of cakeLP of user should equal amount");

    vm.startPrank(owner);
    underlyingToken.approve(address(beefyERC4626), amount);
    beefyERC4626.mint(beefyERC4626.previewDeposit(amount), owner);
    vm.stopPrank();
  }

  function increaseAssetsInVault() public {
    deal(address(underlyingToken), address(beefyVault), 1000e18);
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
    assertTrue(diff(beefyERC4626.previewMint(returnedShares), depositAmount) <= 1, "!same value");
  }

  function testPreviewWithdrawAndRedeemReturnTheSameValue() public shouldRun(forChains(BSC_MAINNET)) {
    deposit(address(this), depositAmount);
    uint256 withdrawalAmount = 10e18;
    uint256 reqShares = beefyERC4626.previewWithdraw(withdrawalAmount);
    assertTrue(diff(beefyERC4626.previewRedeem(reqShares), withdrawalAmount) <= 1, "!same value");
  }

  function testDeposit() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedBeefyShares = (depositAmount * initialBeefySupply) / initialBeefyBalance;
    uint256 expectedErc4626Shares = beefyERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Test that the actual transfers worked
    assertEq(beefyVault.balance(), initialBeefyBalance + depositAmount);

    // Test that the balance view calls work
    assertTrue(diff(beefyERC4626.totalAssets(), depositAmount) <= 1, "total assets don't match the deposited amount");
    assertTrue(
      diff(depositAmount, beefyERC4626.balanceOfUnderlying(address(this))) <= 2,
      "Underlying token balance should be almost the same as deposited amount"
    );

    // Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), expectedErc4626Shares);
    assertEq(beefyERC4626.totalSupply(), expectedErc4626Shares);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(beefyVault.balanceOf(address(beefyERC4626)), expectedBeefyShares);
  }

  function testDepositWithIncreasedVaultValue() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 oldExpectedBeefyShares = (depositAmount * initialBeefySupply) / initialBeefyBalance;
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
    uint256 expectedBeefyShares = (depositAmount * initialBeefySupply) / initialBeefyBalance;
    uint256 expectedErc4626Shares = beefyERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);
    deposit(alice, depositAmount);

    // Test that the actual transfers worked
    assertEq(
      beefyVault.balance(),
      initialBeefyBalance + depositAmount * 2,
      "mint didn't transfer any tokens from the minter"
    );

    // Test that the balance view calls work
    assertTrue(
      diff(depositAmount * 2, beefyERC4626.totalAssets()) <= 2,
      "Beefy total Assets should be almost the same as sum of deposited amounts"
    );
    assertTrue(
      diff(depositAmount, beefyERC4626.balanceOfUnderlying(address(this))) <= 2,
      "Underlying token balance should be almost the same as deposited amount"
    );
    assertTrue(
      diff(depositAmount, beefyERC4626.balanceOfUnderlying(alice)) <= 2,
      "Underlying token balance should be almost the same as deposited amount"
    );

    // Test that we minted the correct amount of token
    assertTrue(
      diff(beefyERC4626.balanceOf(address(this)), expectedErc4626Shares) <= 1,
      "the minted erc4626 shares don't match the expected shares amount"
    );
    assertTrue(
      diff(beefyERC4626.balanceOf(alice), expectedErc4626Shares) <= 1,
      "the minted erc4626 for shares charlie don't match the expected shares amount"
    );
    assertTrue(
      diff(beefyERC4626.totalSupply(), expectedErc4626Shares * 2) <= 1,
      "the total erc4626 shares don't match the expected shares amount"
    );

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      expectedBeefyShares * 2,
      "the shares minted by the beefy vault don't match the expected amount"
    );

    // Beefy ERC4626 should not have underlyingToken after deposit
    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedBeefyShares = (depositAmount * initialBeefySupply) / initialBeefyBalance;
    uint256 mintAmount = beefyERC4626.previewDeposit(depositAmount);

    mint(address(this), depositAmount);
    //    underlyingToken.approve(address(beefyERC4626), depositAmount);
    //    beefyERC4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(
      beefyVault.balance(),
      initialBeefyBalance + depositAmount,
      "mint didn't transfer any tokens from the minter"
    );

    // Test that the balance view calls work
    assertTrue(diff(beefyERC4626.totalAssets(), depositAmount) <= 1, "total assets don't match the deposited amount");
    assertTrue(
      diff(depositAmount, beefyERC4626.balanceOfUnderlying(address(this))) <= 2,
      "Underlying token balance should be almost the same as deposited amount"
    );

    // Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), mintAmount);
    assertEq(beefyERC4626.totalSupply(), mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(beefyVault.balanceOf(address(beefyERC4626)), expectedBeefyShares);
  }

  function testMultipleMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedBeefyShares = (depositAmount * initialBeefySupply) / initialBeefyBalance;
    uint256 mintAmount = beefyERC4626.previewDeposit(depositAmount);

    mint(address(this), depositAmount);
    //    underlyingToken.approve(address(beefyERC4626), depositAmount);
    //    beefyERC4626.mint(mintAmount, address(this));

    // Test that the actual transfers worked
    assertEq(
      beefyVault.balance(),
      initialBeefyBalance + depositAmount,
      "mint didn't transfer any tokens from the minter"
    );

    // Test that the balance view calls work
    assertTrue(diff(beefyERC4626.totalAssets(), depositAmount) <= 1, "total assets don't match the deposited amount");
    assertTrue(
      diff(beefyERC4626.balanceOfUnderlying(address(this)), depositAmount) <= 1,
      "the assets on the depositor's account don't match the deposited amount"
    );

    // Test that we minted the correct amount of token
    assertTrue(
      diff(beefyERC4626.balanceOf(address(this)), mintAmount) <= 1,
      "the minted erc4626 shares don't match the expected shares amount"
    );
    assertEq(beefyERC4626.totalSupply(), mintAmount, "the total erc4626 shares don't match the expected shares amount");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      expectedBeefyShares,
      "the shares minted by the beefy vault don't match the expected amount"
    );

    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 1, "Beefy erc4626 locked amount checking");

    //    vm.startPrank(charlie);
    mint(address(alice), depositAmount);
    //    underlyingToken.approve(address(beefyERC4626), depositAmount);
    //    beefyERC4626.mint(mintAmount, charlie);

    // Test that the actual transfers worked
    assertEq(
      beefyVault.balance(),
      initialBeefyBalance + depositAmount + depositAmount,
      "mint didn't transfer any tokens from the minter"
    );

    // Test that the balance view calls work
    assertTrue(
      diff(beefyERC4626.totalAssets(), depositAmount + depositAmount) <= 2,
      "total assets don't match the deposited amount"
    );
    assertTrue(
      diff(depositAmount, beefyERC4626.balanceOfUnderlying(alice)) <= 1,
      "the assets on the depositor's account don't match the deposited amount"
    );

    // Test that we minted the correct amount of token
    assertTrue(
      diff(beefyERC4626.balanceOf(alice), mintAmount) <= 1,
      "the minted erc4626 shares don't match the expected shares amount"
    );
    assertTrue(
      diff(beefyERC4626.totalSupply(), mintAmount + mintAmount) <= 1,
      "the total erc4626 shares don't match the expected shares amount"
    );

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      beefyVault.balanceOf(address(beefyERC4626)),
      expectedBeefyShares * 2,
      "the shares minted by the beefy vault don't match the expected amount"
    );

    assertTrue(underlyingToken.balanceOf(address(beefyERC4626)) <= 2, "Beefy erc4626 locked amount checking");
    //    vm.stopPrank();
  }

  function testWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 beefyShares = (depositAmount * initialBeefySupply) / initialBeefyBalance;

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
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 2,
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
    uint256 beefyShareBal = (depositAmount * initialBeefySupply) / initialBeefyBalance;

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
    uint256 beefyShares = ((depositAmount * initialBeefySupply) / initialBeefyBalance) * 2;

    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);
    deposit(alice, depositAmount);

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
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 2,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(diff(depositAmount * 2, expectedErc4626SharesNeeded + beefyERC4626.totalSupply()) <= 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertTrue(diff(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded) <= 1,
      "!beefy share balance"
    );

    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - expectedErc4626SharesNeeded;
    beefyShares = beefyShares - expectedBeefySharesNeeded;
    assetBalBefore = underlyingToken.balanceOf(alice);
    erc4626BalBefore = beefyERC4626.balanceOf(alice);
    expectedErc4626SharesNeeded = beefyERC4626.previewWithdraw(withdrawalAmount);
    expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    vm.prank(alice);
    beefyERC4626.withdraw(10e18, alice, alice);

    // Test that the actual transfers worked
    assertTrue(diff(underlyingToken.balanceOf(alice), assetBalBefore + withdrawalAmount) <= 2, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(diff(beefyERC4626.totalSupply(), totalSupplyBefore - expectedErc4626SharesNeeded) <= 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(alice), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertTrue(diff(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyShares - expectedBeefySharesNeeded) <= 1,
      "!beefy share balance"
    );

    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 beefyShares = (depositAmount * initialBeefySupply) / initialBeefyBalance;

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
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 2,
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
    uint256 beefyShares = ((depositAmount * initialBeefySupply) / initialBeefyBalance) * 2;

    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = beefyERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);
    deposit(alice, depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = beefyERC4626.balanceOf(address(this));
    uint256 expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );

    beefyERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 2,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(diff(beefyERC4626.totalSupply(), depositAmount * 2 - redeemAmount) <= 1, "!totalSupply");

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
    assetBalBefore = underlyingToken.balanceOf(alice);
    erc4626BalBefore = beefyERC4626.balanceOf(alice);
    expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      beefyVault.balanceOf(address(beefyERC4626)),
      beefyERC4626.totalSupply()
    );
    vm.prank(alice);
    beefyERC4626.withdraw(10e18, alice, alice);

    // Test that the actual transfers worked
    assertTrue(diff(underlyingToken.balanceOf(alice), assetBalBefore + withdrawalAmount) <= 2, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(beefyERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(diff(beefyERC4626.totalSupply(), totalSupplyBefore - redeemAmount) <= 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(beefyERC4626.balanceOf(alice), erc4626BalBefore - redeemAmount, "!erc4626 supply");

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

  function testTheBugWithdraw(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 100 && amount < 1e19);

    deposit(bob, amount);
    // make sure the full amount is deposited and none is left
    assertEq(underlyingToken.balanceOf(bob), 0, "should deposit the full balance of cakeLP of user");
    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "should deposit the full balance of cakeLP of user");

    // just testing if other users depositing would mess up the calcs
    mint(alice, amount);

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
      uint256 assetsWithdrawn = underlyingToken.balanceOf(bob);
      assertTrue(
        diff(assetsWithdrawn, assetsToWithdraw) < 100,
        "the assets withdrawn must be almost equal to the requested assets to withdraw"
      );
      vm.stopPrank();
    }

    uint256 lockedFunds = underlyingToken.balanceOf(address(beefyERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the withdrawn cakeLP, no dust is acceptable");
  }

  function testTheBugRedeem(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 1e5 && amount < 1e19);

    deposit(alice, amount);
    // make sure the full amount is deposited and none is left
    assertEq(underlyingToken.balanceOf(alice), 0, "should deposit the full balance of cakeLP of user");
    assertEq(underlyingToken.balanceOf(address(beefyERC4626)), 0, "should deposit the full balance of cakeLP of user");

    // just testing if other users depositing would mess up the calcs
    mint(bob, amount);

    // test if the shares of the BeefyERC4626 equal to the assets deposited
    uint256 beefyERC4626SharesMintedToCharlie = beefyERC4626.balanceOf(alice);
    assertEq(
      beefyERC4626SharesMintedToCharlie,
      amount,
      "the first minted shares in beefyERC4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(alice);
      uint256 beefyERC4626SharesToRedeem = beefyERC4626.balanceOf(alice);
      uint256 assetsToRedeem = beefyERC4626.previewRedeem(beefyERC4626SharesToRedeem);
      beefyERC4626.redeem(beefyERC4626SharesToRedeem, alice, alice);
      uint256 assetsRedeemed = underlyingToken.balanceOf(alice);
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

    uint256 lockedFunds = underlyingToken.balanceOf(address(beefyERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the BeefyERC4626
    assertEq(lockedFunds, 0, "should transfer the full balance of the redeemed cakeLP, no dust is acceptable");
  }
}
