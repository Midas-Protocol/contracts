// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/MarketsTest.t.sol";
import { CompoundMarketERC4626 } from "../ionic/strategies/CompoundMarketERC4626.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";
import { IComptroller } from "../compound/ComptrollerInterface.sol";

import { OptimizedAPRVaultExtension } from "../ionic/vault/OptimizedAPRVaultExtension.sol";
import { OptimizedAPRVaultFirstExtension } from "../ionic/vault/OptimizedAPRVaultFirstExtension.sol";
import { OptimizedAPRVaultSecondExtension } from "../ionic/vault/OptimizedAPRVaultSecondExtension.sol";
import { VaultFees } from "../ionic/vault/IVault.sol";
import { OptimizedVaultsRegistry } from "../ionic/vault/OptimizedVaultsRegistry.sol";
import { AdapterConfig } from "../ionic/vault/OptimizedAPRVaultStorage.sol";
import { OptimizedAPRVaultBase } from "../ionic/vault/OptimizedAPRVaultBase.sol";
import { IonicFlywheel } from "../ionic/strategies/flywheel/IonicFlywheel.sol";

import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { WETH } from "solmate/tokens/WETH.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MathUpgradeable as Math } from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC4626Upgradeable as IERC4626 } from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";
import { IERC20MetadataUpgradeable as IERC20Metadata } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

interface TwoBRL is IERC20Metadata {
  function minter() external view returns (address);

  function mint(address to, uint256 amount) external;
}

contract OptimizedAPRVaultTest is MarketsTest {
  address ankrWbnbMarketAddress = 0x57a64a77f8E4cFbFDcd22D5551F52D675cc5A956;
  address ahWbnbMarketAddress = 0x059c595f19d6FA9f8203F3731DF54455cD248c44;
  address wbnbWhale = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;

  address twoBrlAddress = 0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9;
  address twoBrlMarketAddress = 0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba; // DDD and EPX rewards
  address twoBrlWhale = address(255);
  address dddAddress = 0x84c97300a190676a19D1E13115629A11f8482Bd1;
  address epxAddress = 0xAf41054C1487b0e5E2B9250C0332eCBCe6CE9d71;

  uint256 depositAmount = 1e18;
  uint256 blocksPerYear = 20 * 24 * 365 * 60; //blocks per year
  WETH wbnb;
  AdapterConfig[10] adapters;
  ICErc20 ankrWbnbMarket;
  ICErc20 ahWbnbMarket;
  address payable wnativeAddress;
  OptimizedAPRVaultBase vault;
  OptimizedVaultsRegistry registry;
  uint64[] lenderSharesHint = new uint64[](2);
  TwoBRL twoBrl;

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    wnativeAddress = payable(ap.getAddress("wtoken"));
    wbnb = WETH(wnativeAddress);

    if (block.chainid == BSC_MAINNET) {
      ankrWbnbMarket = ICErc20(ankrWbnbMarketAddress);
      ahWbnbMarket = ICErc20(ahWbnbMarketAddress);
      lenderSharesHint[0] = 4e17;
      lenderSharesHint[1] = 6e17;

      _upgradeMarket(CErc20Delegate(ankrWbnbMarketAddress));
      _upgradeMarket(CErc20Delegate(ahWbnbMarketAddress));

      twoBrl = TwoBRL(twoBrlAddress);
      vm.prank(twoBrl.minter());
      twoBrl.mint(twoBrlWhale, 1e19);

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

  function unpauseMarkets() internal {
    IComptroller pool = ankrWbnbMarket.comptroller();

    vm.startPrank(pool.admin());
    pool._setMintPaused(ankrWbnbMarket, false);
    pool._setMintPaused(ahWbnbMarket, false);
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
    IonicFlywheel flywheelLogic = new IonicFlywheel();
    bytes memory params = abi.encode(
      IERC20Metadata(wnativeAddress),
      adapters,
      2, // adapters count
      VaultFees(0, 0, 0, 0),
      address(this),
      type(uint256).max,
      address(registry),
      address(flywheelLogic)
    );

    OptimizedAPRVaultExtension[] memory exts = new OptimizedAPRVaultExtension[](2);
    exts[0] = new OptimizedAPRVaultFirstExtension();
    exts[1] = new OptimizedAPRVaultSecondExtension();
    vault = new OptimizedAPRVaultBase();
    vm.label(address(vault), "vault");
    vault.initialize(exts, params);

    registry.addVault(address(vault));
  }

  function depositAssets() internal {
    vm.startPrank(wbnbWhale);
    wbnb.approve(address(vault), type(uint256).max);
    vault.asSecondExtension().deposit(depositAmount);
    vm.stopPrank();
  }

  function setUpVault() internal {
    unpauseMarkets();

    // make sure there is enough liquidity in the testing markets
    addLiquidity();

    deployVaultRegistry();

    deployAdapters();

    deployVault();

    depositAssets();
  }

  function testVaultEmergencyShutdown() public fork(BSC_MAINNET) {
    OptimizedAPRVaultSecondExtension asSecondExtension = vault.asSecondExtension();
    registry.setEmergencyExit();

    assertTrue(vault.emergencyExit(), "!emergency set");
    assertEq(asSecondExtension.lentTotalAssets(), 0, "!still lending");
    assertGt(asSecondExtension.estimatedTotalAssets(), 0, "!emergency withdrawn");

    asSecondExtension.harvest(lenderSharesHint);
  }

  function testVaultOptimization() public fork(BSC_MAINNET) {
    OptimizedAPRVaultSecondExtension asSecondExtension = vault.asSecondExtension();
    uint256 estimatedAprHint;
    {
      int256[] memory lenderAdjustedAmounts;
      if (lenderSharesHint.length != 0)
        (estimatedAprHint, lenderAdjustedAmounts) = asSecondExtension.estimatedAPR(lenderSharesHint);

      emit log_named_int("lenderAdjustedAmounts0", lenderAdjustedAmounts[0]);
      emit log_named_int("lenderAdjustedAmounts1", lenderAdjustedAmounts[1]);
      emit log_named_uint("hint", estimatedAprHint);
    }

    // log before
    uint256 aprBefore = asSecondExtension.estimatedAPR();
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
      uint256 maxRedeemBefore = asSecondExtension.maxRedeem(wbnbWhale);
      emit log_named_uint("maxRedeemBefore", maxRedeemBefore);

      asSecondExtension.harvest(lenderSharesHint);

      uint256 maxRedeemAfter = asSecondExtension.maxRedeem(wbnbWhale);
      emit log_named_uint("maxRedeemAfter", maxRedeemAfter);
    }

    // check if the APR improved as a result of the hinted better allocations
    {
      uint256 aprAfter = asSecondExtension.estimatedAPR();
      emit log_named_uint("aprAfter", aprAfter);

      if (estimatedAprHint > aprBefore) {
        assertGt(aprAfter, aprBefore, "!harvest didn't optimize the allocations");
      }
    }
  }

  function testVaultPreviewMint(uint256 assets) public fork(BSC_MAINNET) {
    OptimizedAPRVaultSecondExtension asSecondExtension = vault.asSecondExtension();
    vm.assume(assets >= 10 * asSecondExtension.adaptersCount() && assets < type(uint128).max);

    // previewDeposit should return the maximum shares that are minted for the assets input
    uint256 maxShares = asSecondExtension.previewDeposit(assets);
    // previewMint should return the minimum assets required for the shares input
    uint256 shouldBeMoreThanAvailableAssets = asSecondExtension.previewMint(maxShares + 1);
    // minting a share more should require more assets than the available
    assertGt(shouldBeMoreThanAvailableAssets, assets, "!not gt than available assets");
  }

  function testVaultPreviewRedeem(uint256 assets) public fork(BSC_MAINNET) {
    vm.assume(assets < type(uint128).max);
    OptimizedAPRVaultSecondExtension asSecondExtension = vault.asSecondExtension();

    // previewWithdraw should return the maximum shares that are burned for the assets input
    uint256 maxShares = asSecondExtension.previewWithdraw(assets);
    uint256 sameAssets = asSecondExtension.previewRedeem(maxShares);
    uint256 shouldBeMoreThanRequestedAssets = asSecondExtension.previewRedeem(maxShares + 1);
    assertGt(shouldBeMoreThanRequestedAssets, assets, "!not gt than requested assets");

    if (assets > 100) assertEq(sameAssets, assets, "!same");
  }

  function testOptVaultMint(uint256 mintAmount_) public fork(BSC_MAINNET) {
    OptimizedAPRVaultSecondExtension asSecondExtension = vault.asSecondExtension();
    asSecondExtension.harvest(lenderSharesHint);

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    // test the shares before and after calling mint
    {
      uint256 vaultSharesBefore = asSecondExtension.balanceOf(wbnbWhale);
      uint256 whaleAssets = wbnb.balanceOf(wbnbWhale);
      // preview deposit should return the max shares possible for the supplied amount of assets
      uint256 maxShares = asSecondExtension.previewDeposit(whaleAssets);

      // call mint
      bool shouldRevert = true;
      vm.startPrank(wbnbWhale);
      {
        wbnb.approve(address(asSecondExtension), whaleAssets);
        if (asSecondExtension.previewMint(mintAmount_) == 0) vm.expectRevert("too little shares");
        else if (mintAmount_ > maxShares) vm.expectRevert("!insufficient balance");
        else shouldRevert = false;

        asSecondExtension.mint(mintAmount_);
      }
      vm.stopPrank();

      if (!shouldRevert) {
        uint256 vaultSharesAfter = asSecondExtension.balanceOf(wbnbWhale);
        assertEq(vaultSharesAfter - vaultSharesBefore, mintAmount_, "!depositor did not mint the correct shares");
      }
    }
  }

  function testOptVaultDeposit(uint256 depositAmount_) public fork(BSC_MAINNET) {
    OptimizedAPRVaultSecondExtension asSecondExtension = vault.asSecondExtension();
    vm.assume(depositAmount_ >= 10 * asSecondExtension.adaptersCount() && depositAmount_ < type(uint128).max);

    asSecondExtension.harvest(lenderSharesHint);

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    // test the shares before and after calling deposit
    {
      uint256 vaultSharesBefore = asSecondExtension.balanceOf(wbnbWhale);
      uint256 whaleAssets = wbnb.balanceOf(wbnbWhale);
      uint256 expectedVaultSharesMinted = asSecondExtension.previewDeposit(depositAmount_);

      // call deposit
      bool shouldRevert = true;
      vm.startPrank(wbnbWhale);
      {
        wbnb.approve(address(asSecondExtension), whaleAssets);
        if (depositAmount_ > whaleAssets) vm.expectRevert("!insufficient balance");
        else if (expectedVaultSharesMinted == 0) vm.expectRevert("too little assets");
        else shouldRevert = false;

        asSecondExtension.deposit(depositAmount_);
      }
      vm.stopPrank();

      if (!shouldRevert) {
        uint256 vaultSharesAfter = asSecondExtension.balanceOf(wbnbWhale);
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

    OptimizedAPRVaultSecondExtension asSecondExtension = vault.asSecondExtension();
    asSecondExtension.harvest(lenderSharesHint);

    // deposit some assets to test a wider range of withdrawable amounts
    vm.startPrank(wbnbWhale);
    uint256 whaleAssets = wbnb.balanceOf(wbnbWhale);
    wbnb.approve(address(asSecondExtension), whaleAssets);
    asSecondExtension.deposit(whaleAssets / 2);
    vm.stopPrank();

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    // test the balance before and after calling withdraw
    {
      uint256 wbnbBalanceBefore = wbnb.balanceOf(wbnbWhale);

      uint256 maxWithdrawWhale = asSecondExtension.maxWithdraw(wbnbWhale);

      // call withdraw
      bool shouldRevert = true;
      vm.startPrank(wbnbWhale);
      {
        if (withdrawAmount_ > maxWithdrawWhale) vm.expectRevert("ERC20: burn amount exceeds balance");
        else if (withdrawAmount_ == 0) vm.expectRevert("too little assets");
        else shouldRevert = false;

        asSecondExtension.withdraw(withdrawAmount_);
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

    OptimizedAPRVaultSecondExtension asSecondExtension = vault.asSecondExtension();
    asSecondExtension.harvest(lenderSharesHint);

    // deposit some assets to test a wider range of redeemable amounts
    vm.startPrank(wbnbWhale);
    uint256 whaleAssets = wbnb.balanceOf(wbnbWhale);
    wbnb.approve(address(asSecondExtension), whaleAssets);
    asSecondExtension.deposit(whaleAssets / 2);
    vm.stopPrank();

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    // test the balance before and after calling redeem
    {
      uint256 vaultSharesBefore = asSecondExtension.balanceOf(wbnbWhale);

      uint256 maxRedeemWhale = asSecondExtension.maxRedeem(wbnbWhale);

      uint256 assetsToReceive = asSecondExtension.previewRedeem(redeemAmount_);

      // call redeem
      bool shouldRevert = true;
      vm.startPrank(wbnbWhale);
      {
        if (assetsToReceive == 0) vm.expectRevert("too little shares");
        else if (redeemAmount_ > maxRedeemWhale) vm.expectRevert("ERC20: burn amount exceeds balance");
        else shouldRevert = false;

        asSecondExtension.redeem(redeemAmount_);
      }
      vm.stopPrank();

      if (!shouldRevert) {
        uint256 vaultSharesAfter = asSecondExtension.balanceOf(wbnbWhale);
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

    OptimizedAPRVaultFirstExtension firstExt = vault.asFirstExtension();
    OptimizedAPRVaultSecondExtension secondExt = vault.asSecondExtension();
    firstExt.proposeAdapters(adapters, 3);
    vm.expectRevert(NotPassedQuitPeriod.selector);
    secondExt.changeAdapters();

    vm.warp(block.timestamp + 3.01 days);
    secondExt.changeAdapters();
  }

  function testVaultAccrueRewards() public fork(BSC_MAINNET) {
    IERC20Metadata ddd = IERC20Metadata(dddAddress);
    IERC20Metadata epx = IERC20Metadata(epxAddress);
    address someDeployer = address(321);

    // set up the registry, the vault and the adapter
    {
      // upgrade to enable the aprAfterDeposit fn for the vault
      _upgradeMarket(CErc20Delegate(twoBrlMarketAddress));

      vm.startPrank(someDeployer);
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

      AdapterConfig[10] memory _adapters;
      _adapters[0].adapter = twoBrlMarketAdapter;
      _adapters[0].allocation = 1e18;

      IonicFlywheel flywheelLogic = new IonicFlywheel();

      bytes memory params = abi.encode(
        twoBrl,
        _adapters,
        1,
        VaultFees(0, 0, 0, 0),
        address(this),
        type(uint256).max,
        address(registry),
        address(flywheelLogic)
      );

      OptimizedAPRVaultExtension[] memory exts = new OptimizedAPRVaultExtension[](2);
      exts[0] = new OptimizedAPRVaultFirstExtension();
      exts[1] = new OptimizedAPRVaultSecondExtension();
      vault = new OptimizedAPRVaultBase();
      vm.label(address(vault), "vault");
      vault.initialize(exts, params);

      vault.asFirstExtension().addRewardToken(ddd);
      vault.asFirstExtension().addRewardToken(epx);

      registry.addVault(address(vault));
    }
    vm.stopPrank();

    // deposit some funds
    vm.startPrank(twoBrlWhale);
    twoBrl.approve(address(vault), type(uint256).max);
    // accruing for the first time internally with _afterTokenTransfer
    vault.asSecondExtension().deposit(depositAmount);
    vm.stopPrank();

    {
      // advance time to move away from the first cycle,
      // because the first cycle is initialized with 0 rewards
      vm.warp(block.timestamp + 25 hours);
      vm.roll(block.number + 1000);
    }

    // pull from the adapters the rewards for the new cycle
    vault.asSecondExtension().pullAccruedVaultRewards();

    OptimizedAPRVaultFirstExtension vaultFirstExt = vault.asFirstExtension();
    {
      // TODO figure out why these accrue calls are necessary
      IonicFlywheel flywheelDDD = vaultFirstExt.flywheelForRewardToken(ddd);
      IonicFlywheel flywheelEPX = vaultFirstExt.flywheelForRewardToken(epx);
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
    vm.prank(twoBrlWhale);
    vaultFirstExt.claimRewards();

    // check if any rewards were claimed
    assertGt(ddd.balanceOf(twoBrlWhale), 0, "!received DDD");
    assertGt(epx.balanceOf(twoBrlWhale), 0, "!received EPX");
  }

  function testUpgradeOptVault() public fork(BSC_MAINNET) {
    OptimizedAPRVaultExtension[] memory exts = new OptimizedAPRVaultExtension[](2);
    exts[0] = new TestingFirstExtension();
    exts[1] = new TestingSecondExtension();
    registry.setLatestVaultExtensions(address(vault), exts);

    vault.upgradeVault();

    address[] memory currentExtensions = vault._listExtensions();

    for (uint256 i; i < exts.length; i++) {
      assertEq(address(exts[i]), currentExtensions[i], "!matching");
    }
  }

  function testLensFn() public debuggingOnly fork(BSC_CHAPEL) {
    registry = OptimizedVaultsRegistry(0x353195Bdd4917e1Bdabc9809Dc3E8528b3421FF5);
    registry.getVaultsData();
  }

  // TODO test claiming the rewards for multiple vaults
}

contract TestingFirstExtension is OptimizedAPRVaultExtension {
  function _getExtensionFunctions() external pure virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 1;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.dummy1.selector;

    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }

  function dummy1() public {}
}

contract TestingSecondExtension is OptimizedAPRVaultExtension {
  function _getExtensionFunctions() external pure virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 1;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.dummy2.selector;

    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }

  function dummy2() public {}
}
