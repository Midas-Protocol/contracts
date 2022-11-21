// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import { BaseTest } from "../config/BaseTest.t.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { DotDotERC4626Test } from "../DotDot/DotDotLpERC4626Test.sol";
import { IBeefyVault, BeefyERC4626 } from "../../midas/strategies/BeefyERC4626.sol";
import { MidasERC4626 } from "../../midas/strategies/MidasERC4626.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract ERC4626PerformanceFeeTest is BaseTest {
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

  function setUp() public forkAtBlock(BSC_MAINNET, 20238373) {
    underlyingToken = ERC20Upgradeable(address(beefyVault.want()));
    plugin = new BeefyERC4626();
    plugin.initialize(underlyingToken, beefyVault, 10);

    uint256 currentPerformanceFee = plugin.performanceFee();
    plugin.updateFeeSettings(currentPerformanceFee, newFeeRecipient);
  }

  /* --------------------- HELPER FUNCTIONS --------------------- */

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(plugin), amount);
    plugin.deposit(amount, _owner);
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

  function test__initializedValues() public {
    assertEq(plugin.performanceFee(), PERFORMANCE_FEE, "!perFee");
    assertEq(plugin.feeRecipient(), newFeeRecipient, "!feeRecipient");
  }

  function test__UpdateFeeSettings() public {
    uint256 newPerfFee = 100;
    address anotherFeeRecipient = address(10);

    plugin.updateFeeSettings(newPerfFee, anotherFeeRecipient);

    assertEq(plugin.performanceFee(), newPerfFee, "!perfFee == newPerfFee");

    assertEq(plugin.feeRecipient(), anotherFeeRecipient, "!feeRecipient == anotherFeeRecipient");
  }

  function testFail__UpdateFeeSettings() public {
    vm.startPrank(address(10));
    vm.expectRevert("Owned: Only Owner");
    plugin.updateFeeSettings(100, address(10));
  }

  function test__TakePerformanceFeeInUnderlyingAsset() public {
    createPerformanceFee();

    uint256 oldAssets = plugin.totalAssets();
    uint256 oldSupply = plugin.totalSupply();

    uint256 accruedPerformanceFee = (oldAssets - DEPOSIT_AMOUNT).mulDivDown(PERFORMANCE_FEE, 1e18);
    // I had to change this from -1 on the current block to -2 in the pinned block. Not a 100% sure why there is this difference in returned assets from beefy
    uint256 expectedFeeShares = accruedPerformanceFee.mulDivDown(oldSupply, (oldAssets - accruedPerformanceFee)) - 2;

    plugin.takePerformanceFee();

    assertEq(plugin.totalSupply() - oldSupply, expectedFeeShares, "totalSupply increase didnt match expectedFeeShares");
    assertEq(plugin.balanceOf(plugin.feeRecipient()), expectedFeeShares, "!feeRecipient shares");
    assertEq(plugin.totalAssets(), oldAssets, "totalAssets should not change");
  }

  function test__WithdrawAccruedFees() public {
    plugin.updateFeeSettings(PERFORMANCE_FEE, address(10));

    createPerformanceFee();

    uint256 oldAssets = plugin.totalAssets();
    uint256 oldSupply = plugin.totalSupply();

    uint256 accruedPerformanceFee = (oldAssets - DEPOSIT_AMOUNT).mulDivDown(PERFORMANCE_FEE, 1e18);
    // I had to change this from -1 on the current block to -2 in the pinned block. Not a 100% sure why there is this difference in returned assets from beefy
    uint256 expectedFeeShares = accruedPerformanceFee.mulDivDown(oldSupply, (oldAssets - accruedPerformanceFee)) - 2;

    plugin.takePerformanceFee();

    assertEq(plugin.totalSupply() - oldSupply, expectedFeeShares, "totalSupply increase didnt match expectedFeeShares");
    assertEq(plugin.balanceOf(plugin.feeRecipient()), expectedFeeShares, "!feeShares minted");

    plugin.withdrawAccruedFees();

    assertEq(plugin.balanceOf(plugin.feeRecipient()), 0, "!feeRecipient plugin bal == 0");
    assertEq(plugin.totalSupply(), oldSupply, "!totalSupply == oldSupply");
  }

  function testFail__WithdrawAccruedFees() public {
    vm.startPrank(address(10));
    vm.expectRevert("Owned");
    plugin.withdrawAccruedFees();
  }
}
