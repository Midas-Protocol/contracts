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

interface IBeefyStrategy {
  function withdrwalFee() external returns (uint256);

  function WITHDRAWAL_MAX() external returns (uint256);
}

contract BeefyERC4626AccuralTest is BaseTest {
  using FixedPointMathLib for uint256;

  uint256 PERFORMANCE_FEE = 5e16;
  uint256 DEPOSIT_AMOUNT = 100e18;
  uint256 BPS_DENOMINATOR = 10_000;

  BeefyERC4626 plugin;
  ERC20Upgradeable underlyingToken;
  IBeefyVault beefyVault = IBeefyVault(0x94E85B8E050F3F281CB9597cc0144F1F7AF1fe9B); // BOMB-BTCB LP
  address beefyStrategy = 0xEeBcd7E1f008C52fe5804B306832B7DD317e163D;
  address lpChef = 0x1083926054069AaD75d7238E9B809b0eF9d94e5B;
  address newFeeRecipient = address(5);

  address accountOne = address(1);
  address accountTwo = address(2);
  address accountThree = address(3);

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    underlyingToken = ERC20Upgradeable(address(beefyVault.want()));
    plugin = new BeefyERC4626();
    plugin.initialize(underlyingToken, beefyVault, 10);
    plugin.reinitialize();

    // uint256 currentPerformanceFee = plugin.performanceFee();
    // plugin.updateFeeSettings(currentPerformanceFee, newFeeRecipient);
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

  function createPerformanceFee() public {
    deal(address(underlyingToken), address(this), DEPOSIT_AMOUNT);

    deposit(address(this), DEPOSIT_AMOUNT);

    increaseAssetsInVault();
  }

  /* --------------------- ERC4626 PERFORMANCE FEE TESTS --------------------- */

  function testAccuralVaultAmount() public shouldRun(forChains(BSC_MAINNET)) {
    deal(address(underlyingToken), accountOne, 100e18);
    deal(address(underlyingToken), accountTwo, 100e18);

    depositVault(accountOne, DEPOSIT_AMOUNT);
    deposit(accountTwo, DEPOSIT_AMOUNT);

    uint256 withdrawalShare = plugin.convertToBeefyVaultShares(10e18);

    increaseAssetsInVault();

    vm.warp(block.number + 150);

    vm.prank(accountOne);
    beefyVault.withdrawAll();

    uint256 erc4626Share = ERC20Upgradeable(plugin).balanceOf(accountTwo);

    vm.prank(accountTwo);
    plugin.redeem(erc4626Share, accountTwo, accountTwo);

    uint256 accountOneBalance = underlyingToken.balanceOf(accountOne);
    uint256 accountTwoBalance = underlyingToken.balanceOf(accountTwo);

    assertApproxEqAbs(
      accountOneBalance,
      accountTwoBalance,
      1e17,
      string(abi.encodePacked("!withdrwal balance"))
    );
  }

  function testAccuralERC4626Amount() public shouldRun(forChains(BSC_MAINNET)) {
    deal(address(underlyingToken), accountOne, 100e18);
    deal(address(underlyingToken), accountTwo, 100e18);
    deal(address(underlyingToken), accountThree, 100e18);

    depositVault(accountOne, DEPOSIT_AMOUNT);
    deposit(accountTwo, DEPOSIT_AMOUNT);

    uint256 withdrawalShare = plugin.convertToBeefyVaultShares(10e18);

    increaseAssetsInVault();

    vm.warp(block.number + 150);

    vm.prank(accountOne);
    beefyVault.withdrawAll();

    uint256 erc4626Share = ERC20Upgradeable(plugin).balanceOf(accountTwo);

    vm.prank(accountTwo);
    plugin.redeem(erc4626Share, accountTwo, accountTwo);

    uint256 accountOneBalance = underlyingToken.balanceOf(accountOne);
    uint256 accountTwoBalance = underlyingToken.balanceOf(accountTwo);

    assertApproxEqAbs(
      accountOneBalance,
      accountTwoBalance,
      1e17,
      string(abi.encodePacked("!withdrwal balance"))
    );
  }

}
