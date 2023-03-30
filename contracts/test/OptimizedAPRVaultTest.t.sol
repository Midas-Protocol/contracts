// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";
import "../midas/vault/MultiStrategyVault.sol";
import "../midas/strategies/CompoundMarketERC4626.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC4626Upgradeable as IERC4626, IERC20Upgradeable as IERC20 } from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";
import { WETH } from "solmate/tokens/WETH.sol";

import "../midas/vault/OptimizedAPRVault.sol";
import "../midas/vault/OptimizedVaultsRegistry.sol";

contract OptimizedAPRVaultTest is MarketsTest {
  address ankrWbnbMarketAddress = 0x57a64a77f8E4cFbFDcd22D5551F52D675cc5A956;
  address ahWbnbMarketAddress = 0x059c595f19d6FA9f8203F3731DF54455cD248c44;
  address wbnbWhale = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
  uint256 depositAmount = 1e18;
  uint256 blocksPerYear = 20 * 24 * 365 * 60; //blocks per year
  WETH wbnb;
  AdapterConfig[10] adapters;
  ICErc20 ankrWbnbMarket;
  ICErc20 ahWbnbMarket;
  address payable wnativeAddress;
  OptimizedAPRVault vault;
  OptimizedVaultsRegistry registry;
  uint64[] lenderSharesHint = new uint64[](2);

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    wnativeAddress = payable(ap.getAddress("wtoken"));
    wbnb = WETH(wnativeAddress);
    ankrWbnbMarket = ICErc20(ankrWbnbMarketAddress);
    ahWbnbMarket = ICErc20(ahWbnbMarketAddress);
    lenderSharesHint[0] = 4e17;
    lenderSharesHint[1] = 6e17;

    _upgradeExistingCTokenExtension(CErc20Delegate(ankrWbnbMarketAddress));
    _upgradeExistingCTokenExtension(CErc20Delegate(ahWbnbMarketAddress));

    setUpVault();
  }

  function deployVaultRegistry() internal {
    registry = new OptimizedVaultsRegistry();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(registry), address(dpa), "");
      registry = OptimizedVaultsRegistry(address(proxy));
    }
    registry.initialize();
  }

  function addLiquidity() internal {
    vm.startPrank(wbnbWhale);
    wbnb.approve(ankrWbnbMarketAddress, depositAmount * 10);
    ankrWbnbMarket.mint(depositAmount * 10);
    wbnb.approve(ahWbnbMarketAddress, depositAmount * 10);
    ahWbnbMarket.mint(depositAmount * 10);
    vm.stopPrank();
  }

  function deployAdapters() internal {
    CompoundMarketERC4626 ankrMarketAdapter = new CompoundMarketERC4626();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(ankrMarketAdapter), address(dpa), "");
      ankrMarketAdapter = CompoundMarketERC4626(address(proxy));
      vm.label(address(ankrMarketAdapter), "ankrMarketAdapter");
    }
    ankrMarketAdapter.initialize(
      ankrWbnbMarket,
      20 * 24 * 365 * 60, //blocks per year
      registry
    );
    uint256 ankrMarketApr = ankrMarketAdapter.apr();
    emit log_named_uint("ankrMarketApr", ankrMarketApr);

    CompoundMarketERC4626 ahMarketAdapter = new CompoundMarketERC4626();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(ahMarketAdapter), address(dpa), "");
      ahMarketAdapter = CompoundMarketERC4626(address(proxy));
      vm.label(address(ahMarketAdapter), "ahMarketAdapter");
    }
    ahMarketAdapter.initialize(ahWbnbMarket, blocksPerYear, registry);
    uint256 ahMarketApr = ahMarketAdapter.apr();
    emit log_named_uint("ahMarketApr", ahMarketApr);

    adapters[0].adapter = ankrMarketAdapter;
    adapters[0].allocation = 1e17;
    adapters[1].adapter = ahMarketAdapter;
    adapters[1].allocation = 9e17;
  }

  function deployVault() internal {
    vault = new OptimizedAPRVault();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), address(dpa), "");
    vault = OptimizedAPRVault(address(proxy));
    vm.label(address(vault), "vault");

    vault.initializeWithRegistry(
      IERC20(wnativeAddress),
      adapters,
      2, // adapters count
      VaultFees(0, 0, 0, 0),
      address(this),
      type(uint256).max,
      address(this),
      address(registry)
    );

    registry.addVault(address(vault));
  }

  function depositAssets() internal {
    vm.startPrank(wbnbWhale);
    wbnb.approve(address(vault), type(uint256).max);
    vault.deposit(depositAmount);
    vm.stopPrank();
  }

  function setUpVault() internal {
    // make sure there is enough liquidity in the testing markets
    addLiquidity();

    deployVaultRegistry();

    deployAdapters();

    deployVault();

    depositAssets();
  }

  function testVaultEmergencyShutdown() public fork(BSC_MAINNET) {
    registry.setEmergencyExit();

    assertTrue(vault.emergencyExit(), "!emergency set");
    assertEq(vault.lentTotalAssets(), 0, "!still lending");
    assertGt(vault.estimatedTotalAssets(), 0, "!emergency withdrawn");

    vault.harvest(lenderSharesHint);
  }

  function testVaultOptimization() public fork(BSC_MAINNET) {
    uint256 estimatedAprHint;
    {
      int256[] memory lenderAdjustedAmounts;
      if (lenderSharesHint.length != 0)
        (estimatedAprHint, lenderAdjustedAmounts) = vault.estimatedAPR(lenderSharesHint);

      emit log_named_int("lenderAdjustedAmounts0", lenderAdjustedAmounts[0]);
      emit log_named_int("lenderAdjustedAmounts1", lenderAdjustedAmounts[1]);
      emit log_named_uint("hint", estimatedAprHint);
    }

    // log before
    uint256 aprBefore = vault.estimatedAPR();
    {
      emit log_named_uint("aprBefore", aprBefore);

      if (estimatedAprHint > aprBefore) {
        emit log("harvest will rebalance");
      } else {
        emit log("harvest will NOT rebalance");
      }
    }

    // harvest
    {
      uint256 maxRedeemBefore = vault.maxRedeem(wbnbWhale);
      emit log_named_uint("maxRedeemBefore", maxRedeemBefore);

      vault.harvest(lenderSharesHint);

      uint256 maxRedeemAfter = vault.maxRedeem(wbnbWhale);
      emit log_named_uint("maxRedeemAfter", maxRedeemAfter);
    }

    // check if the APR improved as a result of the hinted better allocations
    {
      uint256 aprAfter = vault.estimatedAPR();
      emit log_named_uint("aprAfter", aprAfter);

      if (estimatedAprHint > aprBefore) {
        assertGt(aprAfter, aprBefore, "!harvest didn't optimize the allocations");
      }
    }
  }

  function testVaultPreviewMint(uint256 assets) public fork(BSC_MAINNET) {
    vm.assume(assets >= 10 * vault.adapterCount() && assets < type(uint128).max);
    // previewDeposit should return the maximum shares that are minted for the assets input
    uint256 maxShares = vault.previewDeposit(assets);
    // previewMint should return the minimum assets required for the shares input
    uint256 shouldBeMoreThanAvailableAssets = vault.previewMint(maxShares + 1);
    // minting a share more should require more assets than the available
    assertGt(shouldBeMoreThanAvailableAssets, assets, "!not gt than available assets");
  }

  function testVaultPreviewRedeem(uint256 assets) public fork(BSC_MAINNET) {
    vm.assume(assets < type(uint128).max);
    // previewWithdraw should return the maximum shares that are burned for the assets input
    uint256 maxShares = vault.previewWithdraw(assets);
    uint256 sameAssets = vault.previewRedeem(maxShares);
    uint256 shouldBeMoreThanRequestedAssets = vault.previewRedeem(maxShares + 1);
    assertGt(shouldBeMoreThanRequestedAssets, assets, "!not gt than requested assets");

    if (assets > 100) assertEq(sameAssets, assets, "!same");
  }

  function testOptVaultMint(uint256 mintAmount_) public fork(BSC_MAINNET) {
    vm.assume(mintAmount_ >= 20);

    vault.harvest(lenderSharesHint);

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    // test the shares before and after calling mint
    {
      uint256 vaultSharesBefore = vault.balanceOf(wbnbWhale);
      uint256 whaleAssets = wbnb.balanceOf(wbnbWhale);
      // preview deposit should return the max shares possible for the supplied amount of assets
      uint256 maxShares = vault.previewDeposit(whaleAssets);

      // call mint
      bool shouldRevert = true;
      vm.startPrank(wbnbWhale);
      {
        wbnb.approve(address(vault), whaleAssets);
        if (vault.previewMint(mintAmount_) == 0) vm.expectRevert("too little shares");
        else if (mintAmount_ > maxShares) vm.expectRevert("!insufficient balance");
        else shouldRevert = false;

        vault.mint(mintAmount_);
      }
      vm.stopPrank();

      if (!shouldRevert) {
        uint256 vaultSharesAfter = vault.balanceOf(wbnbWhale);
        assertEq(vaultSharesAfter - vaultSharesBefore, mintAmount_, "!depositor did not mint the correct shares");
      }
    }
  }

  function testOptVaultDeposit(uint256 depositAmount_) public fork(BSC_MAINNET) {
    vm.assume(depositAmount_ >= 10 * vault.adapterCount() && depositAmount_ < type(uint128).max);

    vault.harvest(lenderSharesHint);

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    // test the shares before and after calling deposit
    {
      uint256 vaultSharesBefore = vault.balanceOf(wbnbWhale);
      uint256 whaleAssets = wbnb.balanceOf(wbnbWhale);
      uint256 expectedVaultSharesMinted = vault.previewDeposit(depositAmount_);

      // call deposit
      bool shouldRevert = true;
      vm.startPrank(wbnbWhale);
      {
        wbnb.approve(address(vault), whaleAssets);
        if (depositAmount_ > whaleAssets) vm.expectRevert("!insufficient balance");
        else if (expectedVaultSharesMinted == 0) vm.expectRevert("too little assets");
        else shouldRevert = false;

        vault.deposit(depositAmount_);
      }
      vm.stopPrank();

      if (!shouldRevert) {
        uint256 vaultSharesAfter = vault.balanceOf(wbnbWhale);
        assertEq(
          vaultSharesAfter - vaultSharesBefore,
          expectedVaultSharesMinted,
          "!depositor did not receive the expected minted shares"
        );
      }
    }
  }

  function testOptVaultWithdraw(uint256 withdrawAmount_) public fork(BSC_MAINNET) {
    vm.assume(withdrawAmount_ < type(uint128).max);

    vault.harvest(lenderSharesHint);

    // deposit some assets to test a wider range of withdrawable amounts
    vm.startPrank(wbnbWhale);
    uint256 whaleAssets = wbnb.balanceOf(wbnbWhale);
    wbnb.approve(address(vault), whaleAssets);
    vault.deposit(whaleAssets / 2);
    vm.stopPrank();

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    // test the balance before and after calling withdraw
    {
      uint256 wbnbBalanceBefore = wbnb.balanceOf(wbnbWhale);

      uint256 maxWithdrawWhale = vault.maxWithdraw(wbnbWhale);

      // call withdraw
      bool shouldRevert = true;
      vm.startPrank(wbnbWhale);
      {
        if (withdrawAmount_ > maxWithdrawWhale) vm.expectRevert("ERC20: burn amount exceeds balance");
        else if (withdrawAmount_ == 0) vm.expectRevert("too little assets");
        else shouldRevert = false;

        vault.withdraw(withdrawAmount_);
      }
      vm.stopPrank();

      if (!shouldRevert) {
        uint256 wbnbBalanceAfter = wbnb.balanceOf(wbnbWhale);
        assertEq(
          wbnbBalanceAfter - wbnbBalanceBefore,
          withdrawAmount_,
          "!depositor did not receive the requested withdraw amount"
        );
      }
    }
  }

  function testOptVaultRedeem(uint256 redeemAmount_) public fork(BSC_MAINNET) {
    vm.assume(redeemAmount_ < type(uint128).max);

    vault.harvest(lenderSharesHint);

    // deposit some assets to test a wider range of redeemable amounts
    vm.startPrank(wbnbWhale);
    uint256 whaleAssets = wbnb.balanceOf(wbnbWhale);
    wbnb.approve(address(vault), whaleAssets);
    vault.deposit(whaleAssets / 2);
    vm.stopPrank();

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    // test the balance before and after calling redeem
    {
      uint256 vaultSharesBefore = vault.balanceOf(wbnbWhale);

      uint256 maxRedeemWhale = vault.maxRedeem(wbnbWhale);

      uint256 assetsToReceive = vault.previewRedeem(redeemAmount_);

      // call redeem
      bool shouldRevert = true;
      vm.startPrank(wbnbWhale);
      {
        if (assetsToReceive == 0) vm.expectRevert("too little shares");
        else if (redeemAmount_ > maxRedeemWhale) vm.expectRevert("ERC20: burn amount exceeds balance");
        else shouldRevert = false;

        vault.redeem(redeemAmount_);
      }
      vm.stopPrank();

      if (!shouldRevert) {
        uint256 vaultSharesAfter = vault.balanceOf(wbnbWhale);
        assertEq(vaultSharesBefore - vaultSharesAfter, redeemAmount_, "!depositor did not redeem the requested shares");
      }
    }
  }

  function testDirectAdaptersDeposit() public fork(BSC_MAINNET) {
    vm.startPrank(wbnbWhale);
    wbnb.approve(address(adapters[0].adapter), 10);
    vm.expectRevert("!caller not a vault");
    adapters[0].adapter.deposit(10, wbnbWhale);
  }

  error NotPassedQuitPeriod();

  function testChangeAdapters() public fork(BSC_MAINNET) {
    CompoundMarketERC4626 ahMarketAdapter = new CompoundMarketERC4626();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(ahMarketAdapter), address(dpa), "");
      ahMarketAdapter = CompoundMarketERC4626(address(proxy));
      vm.label(address(ahMarketAdapter), "ahMarketAdapter");
    }
    ahMarketAdapter.initialize(ahWbnbMarket, blocksPerYear, registry);
    adapters[2].adapter = ahMarketAdapter;

    adapters[0].allocation = 8e17;
    adapters[1].allocation = 1e17;
    adapters[2].allocation = 1e17;

    vault.proposeAdapters(adapters, 3);
    vm.expectRevert(NotPassedQuitPeriod.selector);
    vault.changeAdapters();

    vm.warp(block.timestamp + 3.01 days);
    vault.changeAdapters();
  }
}
