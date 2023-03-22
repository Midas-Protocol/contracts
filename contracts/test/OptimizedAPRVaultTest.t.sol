// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";
import "../midas/vault/MultiStrategyVault.sol";
import "../midas/strategies/CompoundMarketERC4626.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC4626Upgradeable as IERC4626, IERC20Upgradeable as IERC20 } from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";
import { WETH } from "solmate/tokens/WETH.sol";

import "../midas/vault/OptimizedAPRVault.sol";
import "../midas/vault/OptimizedVaultsRegistry.sol";

import "./ExtensionsTest.sol";

contract OptimizedAPRVaultTest is ExtensionsTest {
  address ankrWbnbMarketAddress = 0x57a64a77f8E4cFbFDcd22D5551F52D675cc5A956;
  address ahWbnbMarketAddress = 0x059c595f19d6FA9f8203F3731DF54455cD248c44;
  address wbnbWhale = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
  uint256 depositAmount = 1e18;
  uint256 blocksPerYear = 20 * 24 * 365 * 60; //blocks per year

  function testVaultRegistry() public {
    OptimizedVaultsRegistry registry = new OptimizedVaultsRegistry();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(registry), address(dpa), "");
      registry = OptimizedVaultsRegistry(address(proxy));
    }
    registry.initialize();
  }

  function testVaultOptimization() public debuggingOnly fork(BSC_MAINNET) {
    address payable wnativeAddress = payable(ap.getAddress("wtoken"));
    ICErc20 ankrWbnbMarket = ICErc20(ankrWbnbMarketAddress);
    ICErc20 ahWbnbMarket = ICErc20(ahWbnbMarketAddress);
    WETH wbnb = WETH(wnativeAddress);
    AdapterConfig[10] memory adapters;

    {
      // make sure there is enough liquidity
      vm.startPrank(wbnbWhale);
      wbnb.approve(ankrWbnbMarketAddress, depositAmount * 10);
      ankrWbnbMarket.mint(depositAmount * 10);
      wbnb.approve(ahWbnbMarketAddress, depositAmount * 10);
      ahWbnbMarket.mint(depositAmount * 10);
      vm.stopPrank();
    }
    {
      _upgradeExistingCTokenExtension(CErc20Delegate(ankrWbnbMarketAddress));
      _upgradeExistingCTokenExtension(CErc20Delegate(ahWbnbMarketAddress));

      CompoundMarketERC4626 ankrMarketAdapter = new CompoundMarketERC4626();
      {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
          address(ankrMarketAdapter),
          address(dpa),
          ""
        );
        ankrMarketAdapter = CompoundMarketERC4626(address(proxy));
        vm.label(address(ankrMarketAdapter), "ankrMarketAdapter");
      }
      ankrMarketAdapter.initialize(
        ankrWbnbMarket,
        20 * 24 * 365 * 60 //blocks per year
      );
      uint256 ankrMarketApr = ankrMarketAdapter.apr();
      emit log_named_uint("ankrMarketApr", ankrMarketApr);

      CompoundMarketERC4626 ahMarketAdapter = new CompoundMarketERC4626();
      {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(ahMarketAdapter), address(dpa), "");
        ahMarketAdapter = CompoundMarketERC4626(address(proxy));
        vm.label(address(ahMarketAdapter), "ahMarketAdapter");
      }
      ahMarketAdapter.initialize(ahWbnbMarket, blocksPerYear);
      uint256 ahMarketApr = ahMarketAdapter.apr();
      emit log_named_uint("ahMarketApr", ahMarketApr);

      adapters[0].adapter = ankrMarketAdapter;
      adapters[0].allocation = 9e17;
      adapters[1].adapter = ahMarketAdapter;
      adapters[1].allocation = 1e17;
    }

    OptimizedAPRVault vault = new OptimizedAPRVault();
    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), address(dpa), "");
      vault = OptimizedAPRVault(address(proxy));
      vm.label(address(vault), "vault");

      vault.initialize(
        IERC20(wnativeAddress),
        adapters,
        2, // adapters count
        VaultFees(0, 0, 0, 0),
        address(this),
        type(uint256).max,
        address(this)
      );
    }

    vm.startPrank(wbnbWhale);
    wbnb.approve(address(vault), type(uint256).max);
    vault.deposit(depositAmount);
    vm.stopPrank();

    uint64[] memory lenderSharesHint = new uint64[](2);
    lenderSharesHint[0] = 4e17;
    lenderSharesHint[1] = 6e17;

    uint256 currentAPR = vault.estimatedAPR();
    emit log_named_uint("currentAPR", currentAPR);

    uint256 estimatedAprHint;
    {
      int256[] memory lenderAdjustedAmounts;
      if (lenderSharesHint.length != 0)
        (estimatedAprHint, lenderAdjustedAmounts) = vault.estimatedAPR(lenderSharesHint);

      emit log_named_int("lenderAdjustedAmounts0", lenderAdjustedAmounts[0]);
      emit log_named_int("lenderAdjustedAmounts1", lenderAdjustedAmounts[1]);
      emit log_named_uint("hint", estimatedAprHint);

      if (estimatedAprHint > currentAPR) {
        emit log("harvest will rebalance");
      } else {
        emit log("harvest will NOT rebalance");
      }
    }

    uint256 maxRedeemBefore = vault.maxRedeem(wbnbWhale);
    vault.harvest(lenderSharesHint);
    uint256 maxRedeemAfter = vault.maxRedeem(wbnbWhale);
    emit log_named_uint("maxRedeemBefore", maxRedeemBefore);
    emit log_named_uint("maxRedeemAfter", maxRedeemAfter);

    uint256 aprAfter = vault.estimatedAPR();
    emit log_named_uint("aprAfter", aprAfter);

    if (estimatedAprHint > currentAPR) {
      assertGt(aprAfter, currentAPR, "!harvest didn't optimize the allocations");
    }

    uint256 wbnbBalanceBefore = wbnb.balanceOf(wbnbWhale);

    // advance time with a year
    vm.warp(block.timestamp + 365.25 days);
    vm.roll(block.number + blocksPerYear);

    uint256 maxRedeemWhale = vault.maxRedeem(wbnbWhale);
    {
      vm.startPrank(wbnbWhale);
      uint256 previewRed = vault.previewRedeem(maxRedeemWhale);
      emit log_named_uint("previewRed", previewRed);
      vault.redeem(maxRedeemWhale);
      vm.stopPrank();
    }

    uint256 wbnbBalanceAfter = wbnb.balanceOf(wbnbWhale);
    assertGt(wbnbBalanceAfter - wbnbBalanceBefore, depositAmount, "!depositor did not accrue");
  }
}
