// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { IBeefyVault, BeefyERC4626 } from "../midas/strategies/BeefyERC4626.sol";
import { MidasERC4626 } from "../midas/strategies/MidasERC4626.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract BeefyERC4626AccuralTest is BaseTest {
  using FixedPointMathLib for uint256;

  uint256 DEPOSIT_AMOUNT = 100e18;

  BeefyERC4626 plugin;
  ERC20Upgradeable underlyingToken;
  IBeefyVault beefyVault = IBeefyVault(0x94E85B8E050F3F281CB9597cc0144F1F7AF1fe9B); // BOMB-BTCB LP
  address beefyStrategy = 0xEeBcd7E1f008C52fe5804B306832B7DD317e163D;

  address accountOne = address(1);
  address accountTwo = address(2);
  address accountThree = address(3);

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    underlyingToken = ERC20Upgradeable(address(beefyVault.want()));
    plugin = new BeefyERC4626();
    plugin.initialize(underlyingToken, beefyVault, 10);
    plugin.reinitialize();
  }

  /* --------------------- HELPER FUNCTIONS --------------------- */

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(plugin), amount);
    plugin.deposit(amount, _owner);
    vm.stopPrank();
  }

  function depositVault(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(beefyVault), amount);
    beefyVault.deposit(amount);
    vm.stopPrank();
  }

  function increaseAssetsInVault() public {
    deal(address(underlyingToken), address(beefyVault), 1000e18);
    beefyVault.earn();
  }

  /* --------------------- ERC4626 ACCURAL TESTS --------------------- */

  function testAccuralVaultAmount() public shouldRun(forChains(BSC_MAINNET)) {
    deal(address(underlyingToken), accountOne, DEPOSIT_AMOUNT);
    deal(address(underlyingToken), accountTwo, DEPOSIT_AMOUNT);
    deal(address(underlyingToken), accountThree, DEPOSIT_AMOUNT);

    depositVault(accountOne, DEPOSIT_AMOUNT);
    deposit(accountTwo, DEPOSIT_AMOUNT);
    deposit(accountThree, DEPOSIT_AMOUNT);

    // increase vault balance
    increaseAssetsInVault();

    vm.warp(block.number + 150);

    // decrease vault balance
    vm.prank(accountThree);
    beefyVault.withdrawAll();

    vm.warp(block.number + 150);

    vm.prank(accountOne);
    beefyVault.withdrawAll();

    uint256 erc4626Share = ERC20Upgradeable(plugin).balanceOf(accountTwo);

    vm.prank(accountTwo);
    plugin.redeem(erc4626Share, accountTwo, accountTwo);

    uint256 accountOneBalance = underlyingToken.balanceOf(accountOne);
    uint256 accountTwoBalance = underlyingToken.balanceOf(accountTwo);

    assertApproxEqAbs(accountOneBalance, accountTwoBalance, 1e17, string(abi.encodePacked("!withdrwal balance")));
  }

  function testAccuralERC4626Amount() public shouldRun(forChains(BSC_MAINNET)) {
    deal(address(underlyingToken), accountOne, DEPOSIT_AMOUNT);
    deal(address(underlyingToken), accountTwo, DEPOSIT_AMOUNT);
    deal(address(underlyingToken), accountThree, DEPOSIT_AMOUNT);

    depositVault(accountOne, DEPOSIT_AMOUNT);
    deposit(accountTwo, DEPOSIT_AMOUNT);

    // increasing assets in erc4626
    deposit(accountThree, DEPOSIT_AMOUNT);

    vm.warp(block.number + 150);

    // decrease assets in erc4626
    vm.prank(accountThree);
    plugin.withdraw(DEPOSIT_AMOUNT / 2, accountThree, accountThree);

    vm.warp(block.number + 150);

    vm.prank(accountOne);
    beefyVault.withdrawAll();

    uint256 erc4626Share = ERC20Upgradeable(plugin).balanceOf(accountTwo);

    vm.prank(accountTwo);
    plugin.redeem(erc4626Share, accountTwo, accountTwo);

    uint256 accountOneBalance = underlyingToken.balanceOf(accountOne);
    uint256 accountTwoBalance = underlyingToken.balanceOf(accountTwo);

    assertApproxEqAbs(accountOneBalance, accountTwoBalance, 1e17, string(abi.encodePacked("!withdrwal balance")));
  }
}
