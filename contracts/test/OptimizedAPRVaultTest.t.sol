// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";
import { MultiStrategyVault, AdapterConfig, VaultFees } from "../midas/vault/MultiStrategyVault.sol";
import { CompoundMarketERC4626 } from "../midas/strategies/CompoundMarketERC4626.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";

import { MathUpgradeable as Math } from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC4626Upgradeable as IERC4626 } from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { WETH } from "solmate/tokens/WETH.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { OptimizedAPRVault } from "../midas/vault/OptimizedAPRVault.sol";
import { OptimizedVaultsRegistry } from "../midas/vault/OptimizedVaultsRegistry.sol";

import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

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

    if (block.chainid == BSC_MAINNET) {
      ankrWbnbMarket = ICErc20(ankrWbnbMarketAddress);
      ahWbnbMarket = ICErc20(ahWbnbMarketAddress);
      lenderSharesHint[0] = 4e17;
      lenderSharesHint[1] = 6e17;

      _upgradeExistingCTokenExtension(CErc20Delegate(ankrWbnbMarketAddress));
      _upgradeExistingCTokenExtension(CErc20Delegate(ahWbnbMarketAddress));

      setUpVault();
    }
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

    ERC20Upgradeable[] memory rewardTokens = new ERC20Upgradeable[](0);
    vault.initializeWithRegistry(
      ERC20Upgradeable(wnativeAddress),
      adapters,
      2, // adapters count
      VaultFees(0, 0, 0, 0),
      address(this),
      type(uint256).max,
      address(this),
      address(registry),
      rewardTokens
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
    vm.assume(assets >= 10 * vault.adaptersCount() && assets < type(uint128).max);
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
    vm.assume(mintAmount_ > 1e8);

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
    vm.assume(depositAmount_ >= 10 * vault.adaptersCount() && depositAmount_ < type(uint128).max);

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

  address twoBrlAddress = 0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9;
  address twoBrlMarketAddress = 0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba; // DDD and EPX rewards
  address twoBrlWhale = 0x2484AE439894521f57fdC227E16999a636Fb2Fd4;
  address dddAddress = 0x84c97300a190676a19D1E13115629A11f8482Bd1;
  address epxAddress = 0xAf41054C1487b0e5E2B9250C0332eCBCe6CE9d71;

  function testVaultAccrueRewards() public fork(BSC_MAINNET) {
    ERC20Upgradeable twoBrl = ERC20Upgradeable(twoBrlAddress);
    ERC20Upgradeable ddd = ERC20Upgradeable(dddAddress);
    ERC20Upgradeable epx = ERC20Upgradeable(epxAddress);

    // set up the registry, the vault and the adapter
    {
      // upgrade to enable the aprAfterDeposit fn for the vault
      _upgradeExistingCTokenExtension(CErc20Delegate(twoBrlMarketAddress));

      deployVaultRegistry();

      // deploy the adapter
      CompoundMarketERC4626 twoBrlMarketAdapter = new CompoundMarketERC4626();
      {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
          address(twoBrlMarketAdapter),
          address(dpa),
          ""
        );
        twoBrlMarketAdapter = CompoundMarketERC4626(address(proxy));
        vm.label(address(twoBrlMarketAdapter), "twoBrlMarketAdapter");
      }
      twoBrlMarketAdapter.initialize(ICErc20(twoBrlMarketAddress), blocksPerYear, registry);

      // deploy the vault
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
        address(new OptimizedAPRVault()),
        address(dpa),
        ""
      );
      vault = OptimizedAPRVault(address(proxy));
      vm.label(address(vault), "vault");

      ERC20Upgradeable[] memory rewardTokens = new ERC20Upgradeable[](2);
      rewardTokens[0] = ddd;
      rewardTokens[1] = epx;

      AdapterConfig[10] memory _adapters;
      _adapters[0].adapter = twoBrlMarketAdapter;
      _adapters[0].allocation = 1e18;

      vault.initializeWithRegistry(
        twoBrl,
        _adapters,
        1,
        VaultFees(0, 0, 0, 0),
        address(this),
        type(uint256).max,
        address(this),
        address(registry),
        rewardTokens
      );

      registry.addVault(address(vault));
    }

    MidasFlywheel flywheelDDD = vault.flywheels(ddd);
    MidasFlywheel flywheelEPX = vault.flywheels(epx);

    // deposit some funds
    vm.startPrank(twoBrlWhale);
    twoBrl.approve(address(vault), type(uint256).max);
    // accruing for the first time internally with _afterTokenTransfer
    vault.deposit(depositAmount);
    vm.stopPrank();

    {
      // advance time to move away from the first cycle,
      // because the first cycle is initialized with 0 rewards
      vm.warp(block.timestamp + 25 hours);
      vm.roll(block.number + 1000);
    }

    // pull from the adapters the rewards for the new cycle
    vault.claimRewards();

    {
      // TODO figure out why these accrue calls are necessary
      flywheelDDD.accrue(ERC20(address(vault)), twoBrlWhale);
      flywheelEPX.accrue(ERC20(address(vault)), twoBrlWhale);

      // advance time in the same cycle in order to accrue some rewards for it
      vm.warp(block.timestamp + 10 hours);
      vm.roll(block.number + 1000);
    }

    // harvest does nothing when the APR remains the same
    //uint64[] memory array = new uint64[](1);
    //array[0] = 1e18;
    //vault.harvest(array);

    // accrue and claim
    flywheelDDD.accrue(ERC20(address(vault)), twoBrlWhale);
    flywheelDDD.claimRewards(twoBrlWhale);
    flywheelEPX.accrue(ERC20(address(vault)), twoBrlWhale);
    flywheelEPX.claimRewards(twoBrlWhale);

    // check if any rewards were claimed
    assertGt(ddd.balanceOf(twoBrlWhale), 0, "!received DDD");
    assertGt(epx.balanceOf(twoBrlWhale), 0, "!received EPX");
  }

  // TODO test claiming the rewards for multiple vaults
}
