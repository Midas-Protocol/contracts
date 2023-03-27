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

    if (block.chainid == BSC_MAINNET) {
      wbnb = WETH(wnativeAddress);
      ankrWbnbMarket = ICErc20(ankrWbnbMarketAddress);
      ahWbnbMarket = ICErc20(ahWbnbMarketAddress);
      lenderSharesHint[0] = 4e17;
      lenderSharesHint[1] = 6e17;

      _upgradeExistingCTokenExtension(CErc20Delegate(ankrWbnbMarketAddress));
      _upgradeExistingCTokenExtension(CErc20Delegate(ahWbnbMarketAddress));

      setUpVault();
    } else {

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
      2,
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

    // test if the APR improved as a result of the hinted better allocations
    {
      uint256 aprAfter = vault.estimatedAPR();
      emit log_named_uint("aprAfter", aprAfter);

      if (estimatedAprHint > aprBefore) {
        assertGt(aprAfter, aprBefore, "!harvest didn't optimize the allocations");
      }
    }
  }

  function testOptVaultWithdraw() public fork(BSC_MAINNET) {
    vault.harvest(lenderSharesHint);

    // test the balance before and after calling redeem
    {
      uint256 wbnbBalanceBefore = wbnb.balanceOf(wbnbWhale);

      // advance time with a year
      vm.warp(block.timestamp + 365.25 days);
      vm.roll(block.number + blocksPerYear);

      uint256 maxWithdrawWhale = vault.maxWithdraw(wbnbWhale);
      emit log_named_uint("maxWithdrawWhale", maxWithdrawWhale);

      // call redeem
      vm.prank(wbnbWhale);
      vault.withdraw(maxWithdrawWhale);

      uint256 wbnbBalanceAfter = wbnb.balanceOf(wbnbWhale);
      assertGt(
        wbnbBalanceAfter - wbnbBalanceBefore,
        depositAmount,
        "!depositor did not receive more than the initial deposited amount"
      );
    }
  }

  function testOptVaultRedeem() public fork(BSC_MAINNET) {
    vault.harvest(lenderSharesHint);

    // test the balance before and after calling redeem
    {
      uint256 wbnbBalanceBefore = wbnb.balanceOf(wbnbWhale);

      // advance time with a year
      vm.warp(block.timestamp + 365.25 days);
      vm.roll(block.number + blocksPerYear);

      uint256 maxRedeemWhale = vault.maxRedeem(wbnbWhale);
      uint256 assetsFromRedeem = vault.previewRedeem(maxRedeemWhale);
      emit log_named_uint("assetsFromRedeem", assetsFromRedeem);

      // call redeem
      vm.prank(wbnbWhale);
      vault.redeem(maxRedeemWhale);

      uint256 wbnbBalanceAfter = wbnb.balanceOf(wbnbWhale);
      assertGt(
        wbnbBalanceAfter - wbnbBalanceBefore,
        depositAmount,
        "!depositor did not receive more than the initial deposited amount"
      );
    }
  }

  function testOptVaultMint() public fork(BSC_MAINNET) {
    vault.harvest(lenderSharesHint);

    // test the shares before and after calling mint
    {
      uint256 vaultSharesBefore = vault.balanceOf(wbnbWhale);

      // advance time with a year
      vm.warp(block.timestamp + 365.25 days);
      vm.roll(block.number + blocksPerYear);

      uint256 maxMintWhale = vault.maxMint(wbnbWhale);
      maxMintWhale = Math.min(maxMintWhale, wbnb.balanceOf(wbnbWhale));
      maxMintWhale = vault.convertToShares(maxMintWhale);
      emit log_named_uint("maxMintWhale", maxMintWhale);

      // call mint
      vm.startPrank(wbnbWhale);
      wbnb.approve(address(vault), maxMintWhale);
      vault.mint(maxMintWhale);
      vm.stopPrank();

      uint256 vaultSharesAfter = vault.balanceOf(wbnbWhale);
      assertGt(
        vaultSharesAfter - vaultSharesBefore,
        depositAmount,
        "!depositor did not receive more than the initial deposited amount"
      );
    }
  }

  function testOptVaultDeposit() public fork(BSC_MAINNET) {
    vault.harvest(lenderSharesHint);

    // test the shares before and after calling deposit
    {
      uint256 vaultSharesBefore = vault.balanceOf(wbnbWhale);

      // advance time with a year
      vm.warp(block.timestamp + 365.25 days);
      vm.roll(block.number + blocksPerYear);

      uint256 maxDepositWhale = vault.maxDeposit(wbnbWhale);
      maxDepositWhale = Math.min(maxDepositWhale, wbnb.balanceOf(wbnbWhale));
      emit log_named_uint("maxDepositWhale", maxDepositWhale);

      // call deposit
      vm.startPrank(wbnbWhale);
      wbnb.approve(address(vault), maxDepositWhale);
      vault.deposit(maxDepositWhale);
      vm.stopPrank();

      uint256 vaultSharesAfter = vault.balanceOf(wbnbWhale);
      assertGt(
        vaultSharesAfter - vaultSharesBefore,
        depositAmount,
        "!depositor did not receive more than the initial deposited amount"
      );
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
    ERC20Upgradeable[] memory rewardTokens = new ERC20Upgradeable[](2);
    rewardTokens[0] = ERC20Upgradeable(dddAddress);
    rewardTokens[1] = ERC20Upgradeable(epxAddress);

    _upgradeExistingCTokenExtension(CErc20Delegate(twoBrlMarketAddress));

    deployVaultRegistry();

    CompoundMarketERC4626 twoBrlMarketAdapter = new CompoundMarketERC4626();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(twoBrlMarketAdapter), address(dpa), "");
      twoBrlMarketAdapter = CompoundMarketERC4626(address(proxy));
      vm.label(address(twoBrlMarketAdapter), "twoBrlMarketAdapter");
    }
    twoBrlMarketAdapter.initialize(ICErc20(twoBrlMarketAddress), blocksPerYear, registry);

    AdapterConfig[10] memory _adapters;
    _adapters[0].adapter = twoBrlMarketAdapter;
    _adapters[0].allocation = 1e18;

    {
      vault = new OptimizedAPRVault();
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), address(dpa), "");
      vault = OptimizedAPRVault(address(proxy));
      vm.label(address(vault), "vault");

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
    MidasFlywheel flywheelDDD = vault.flywheels(rewardTokens[0]);
    vm.label(address(flywheelDDD), "DDDfw");
    MidasFlywheel flywheelEPX = vault.flywheels(rewardTokens[1]);
    vm.label(address(flywheelEPX), "EPXfw");

    vm.startPrank(twoBrlWhale);
    twoBrl.approve(address(vault), type(uint256).max);
    // accruing for the first time internally with _afterTokenTransfer
    vault.deposit(depositAmount);
    vm.stopPrank();

    {
      FuseFlywheelDynamicRewards rew = FuseFlywheelDynamicRewards(address(flywheelDDD.flywheelRewards()));
      (uint32 start, uint32 end, uint192 reward) = rew.rewardsCycle(ERC20(address(vault)));
      emit log_named_uint("start", start);
      emit log_named_uint("end", end);
      emit log_named_uint("reward", reward);

      // advance time to move to the next cycle
      vm.warp(block.timestamp + 18 hours);
      vm.roll(block.number + 1000);
    }
    {
      flywheelDDD.accrue(ERC20(address(vault)), twoBrlWhale);
      flywheelEPX.accrue(ERC20(address(vault)), twoBrlWhale);

      // advance time to move to the next cycle
      vm.warp(block.timestamp + 18 hours);
      vm.roll(block.number + 1000);
    }
    //    // advance time with a year
    //    vm.warp(block.timestamp + 365.25 days);
    //    vm.roll(block.number + blocksPerYear);

    // harvest does nothing when the APR remains the same
    //uint64[] memory array = new uint64[](1);
    //array[0] = 1e18;
    //vault.harvest(array);

    vault.claimRewards();

    {
      FuseFlywheelDynamicRewards rew = FuseFlywheelDynamicRewards(address(flywheelDDD.flywheelRewards()));

      (uint32 start, uint32 end, uint192 reward) = rew.rewardsCycle(ERC20(address(vault)));
      emit log_named_uint("start", start);
      emit log_named_uint("end", end);
      emit log_named_uint("reward", reward);
    }

    vm.startPrank(twoBrlWhale);
    flywheelDDD.accrue(ERC20(address(vault)), twoBrlWhale);
    flywheelDDD.claimRewards(twoBrlWhale);
    flywheelEPX.accrue(ERC20(address(vault)), twoBrlWhale);
    flywheelEPX.claimRewards(twoBrlWhale);
    vm.stopPrank();

    assertGt(rewardTokens[0].balanceOf(twoBrlWhale), 0, "!received DDD");
    assertGt(rewardTokens[1].balanceOf(twoBrlWhale), 0, "!received EPX");
  }
}
