// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../helpers/WithPool.sol";
import "../config/BaseTest.t.sol";

import { MidasERC4626, HelioERC4626, IJAR } from "../../midas/strategies/HelioERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FlywheelCore, IFlywheelRewards } from "flywheel-v2/FlywheelCore.sol";
import { FuseFlywheelDynamicRewardsPlugin } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewardsPlugin.sol";
import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { Authority } from "solmate/auth/Auth.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

struct RewardsCycle {
  uint32 start;
  uint32 end;
  uint192 reward;
}

contract HelioERC4626Test is AbstractERC4626Test {
  using FixedPointMathLib for uint256;

  IJAR jar;

  constructor() WithPool() {}

  function setUp(string memory _testPreFix, bytes calldata data) public override {
    setUpPool("Helio-test ", false, 0.1e18, 1.1e18);
    sendUnderlyingToken(depositAmount, address(this));

    testPreFix = _testPreFix;

    (address _asset, address _jar) = abi.decode(data, (address, address));

    jar = IJAR(_jar);

    HelioERC4626 jarvisERC4626 = new HelioERC4626();
    jarvisERC4626.initialize(underlyingToken, jar);
    plugin = jarvisERC4626;

    initialStrategyBalance = getStrategyBalance();
  }

  function increaseAssetsInVault() public override {
    deal(address(underlyingToken), address(1), 1e18);
    vm.prank(address(1));
    underlyingToken.transfer(address(jar), 1e18);
  }

  function decreaseAssetsInVault() public override {
    vm.prank(address(jar));
    underlyingToken.transfer(address(1), 2e18);
  }

  function getDepositShares() public view override returns (uint256) {
    uint256 amount = jar.balanceOf(address(plugin));
    return amount;
  }

  function getStrategyBalance() public view override returns (uint256) {
    return jar.totalSupply();
  }

  function getExpectedDepositShares() public view override returns (uint256) {
    return depositAmount;
  }

  function getRedepositRewards(uint256 withdrawnRewards) public view override returns (uint256) {
    return jar.earned(address(plugin)) - withdrawnRewards;
  }

  function getWithdrawalRewards(uint256 withdrawalAmount) public override returns (uint256) {
    vm.warp(block.timestamp + 10);
    return (jar.earned(address(plugin)) * plugin.convertToShares(withdrawalAmount)) / plugin.totalSupply();
  }

  function testInitializedValues(string memory assetName, string memory assetSymbol) public override {
    assertEq(
      plugin.name(),
      string(abi.encodePacked("Midas ", assetName, " Vault")),
      string(abi.encodePacked("!name ", testPreFix))
    );
    assertEq(
      plugin.symbol(),
      string(abi.encodePacked("mv", assetSymbol)),
      string(abi.encodePacked("!symbol ", testPreFix))
    );
    assertEq(address(plugin.asset()), address(underlyingToken), string(abi.encodePacked("!asset ", testPreFix)));
    assertEq(address(HelioERC4626(address(plugin)).jar()), address(jar), string(abi.encodePacked("!jar ", testPreFix)));
  }
}
