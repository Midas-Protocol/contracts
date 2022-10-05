// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { MidasERC4626, BeefyERC4626, IBeefyVault } from "../midas/strategies/BeefyERC4626.sol";

contract BeefyAPRTest is BaseTest {
  using FixedPointMathLib for uint256;

  uint256 bscFork;
  string path = "./contracts/test/beefyAPR.txt";

  IBeefyVault public beefyVault; // ERC4626 => underlyingToken => beefyStrategy
  address public lpChef = 0x1083926054069AaD75d7238E9B809b0eF9d94e5B;

  MidasERC4626 public plugin;
  ERC20Upgradeable public underlyingToken;

  uint256 public depositAmount = 100e18;
  uint256 public BPS_DENOMINATOR = 10_000;
  uint256 public withdrawalFee = 10;

  uint256 public initialStrategyBalance;
  uint256 public initialStrategySupply;

  function setUp() public {
    beefyVault = IBeefyVault(0x80ACf5C89A284C4b6Fdbc851Ba9844D29d4c6BEd);
    underlyingToken = ERC20Upgradeable(0x5887cEa5e2bb7dD36F0C06Da47A8Df918c289A29);
    // BeefyERC4626 beefyERC4626 = new BeefyERC4626();
    // beefyERC4626.initialize(underlyingToken, beefyVault, withdrawalFee);
    // beefyERC4626.reinitialize();
    // plugin = beefyERC4626;

    // initialStrategyBalance = beefyVault.balance();
    // initialStrategySupply = beefyVault.totalSupply();
  }

  function sendUnderlyingToken(uint256 amount, address recipient) public {
    deal(address(underlyingToken), recipient, amount);
  }

  function increaseAssetsInVault() public {
    deal(address(underlyingToken), address(beefyVault), 1000e18);
    beefyVault.earn();
  }

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(plugin), amount);
    plugin.deposit(amount, _owner);
    vm.stopPrank();
  }

  function getDepositShares() public view returns (uint256) {
    return beefyVault.balanceOf(address(plugin));
  }

  function getStrategyBalance() public view returns (uint256) {
    return beefyVault.balance();
  }

  function getExpectedDepositShares() public view returns (uint256) {
    return (depositAmount * beefyVault.totalSupply()) / beefyVault.balance();
  }

  function printPricePerShare(uint256 blockNumber) public {
    uint256 ts = beefyVault.totalSupply();
    uint256 bal = beefyVault.balance();
    uint256 pps = bal.mulDivDown(1e18, ts);
    emit log_uint(blockNumber);
    emit log_named_uint("ts", ts);
    emit log_named_uint("bal", bal);
    emit log_named_uint("pps", pps);
    emit log_string("------------------");
    vm.writeLine(
      path,
      string(
        abi.encodePacked(
          Strings.toString(blockNumber),
          "-",
          Strings.toString(ts),
          ",",
          Strings.toString(bal),
          ",",
          Strings.toString(pps)
        )
      )
    );
  }

  // 21558717 Beefy Vault goes live
  // 21646544 Midas Vault goes live
  // 21921400 current block
  function testHistoricData() public {
    for (uint256 i = 21558717; i < 21921400; i += 28800) {
      bscFork = vm.createFork("https://bsc-mainnet.nodereal.io/v1/1716320ddd3844a7b5fb44c05f67c832", i);
      vm.selectFork(bscFork);
      printPricePerShare(i);
    }
    vm.closeFile(path);
  }
}
