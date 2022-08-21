// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "../../config/BaseTest.t.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IFusePool, IFToken, FusePoolZap } from "fuse-pool-zap/FusePoolZap.sol";

// Using 2BRL
// Tested on block 19052824
contract LiFiZapperTest is BaseTest {
  bool public shouldRunTest;
  FusePoolZap internal zap;

  address internal constant JARVIS_FUSE_POOL = 0x31d76A64Bc8BbEffb601fac5884372DEF910F044;
  address internal constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
  address internal constant FTOKEN = 0xa7213deB44f570646Ea955771Cc7f39B58841363;
  address internal constant DEPOSITOR = 0x30C3002f742ad0811169d307ca39863209c80540;

  constructor() {
    shouldRunTest = forChains(BSC_MAINNET);
  }

  function setUp() public {
    zap = new FusePoolZap();
  }

  function testCanZapIn() public {
    vm.startPrank(DEPOSITOR);

    uint256 amount = 1000 * 10**ERC20(BUSD).decimals();

    ERC20(BUSD).approve(address(zap), amount);
    zap.zapIn(JARVIS_FUSE_POOL, BUSD, amount);

    assertEq(ERC20(FTOKEN).balanceOf(DEPOSITOR) > 0, true);

    vm.stopPrank();
  }
}
