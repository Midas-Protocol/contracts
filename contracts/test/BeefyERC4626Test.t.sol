// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { BeefyERC4626, IBeefyVault } from "../compound/strategies/BeefyERC4626.sol";
import { MockStrategy } from "./mocks/beefy/MockStrategy.sol";
import { MockVault } from "./mocks/beefy/MockVault.sol";
import { IStrategy } from "./mocks/beefy/IStrategy.sol";

contract BeefyERC4626Test is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  BeefyERC4626 beefyERC4626;

  MockERC20 testToken;
  MockStrategy mockStrategy;
  MockVault mockVault;

  uint256 depositAmount = 100e18;

  function setUp() public {
    testToken = new MockERC20("TestToken", "TST", 18);
    mockStrategy = new MockStrategy(address(testToken));
    mockVault = new MockVault(address(mockStrategy), "MockVault", "MV");
    beefyERC4626 = new BeefyERC4626(testToken, "TestVault", "TSTV", IBeefyVault(address(mockVault)));
  }

  function testInitializedValues() public {
    assertEq(beefyERC4626.name(), "TestVault");
    assertEq(beefyERC4626.symbol(), "TSTV");
    assertEq(address(beefyERC4626.asset()), address(testToken));
    assertEq(address(beefyERC4626.beefyVault()), address(mockVault));
  }

  function deposit() public {
    testToken.mint(address(this), depositAmount);
    testToken.approve(address(beefyERC4626), depositAmount);
    beefyERC4626.deposit(depositAmount, address(this));
  }

  function testDeposit() public {
    deposit();
    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), 0);
    assertEq(testToken.balanceOf(address(mockVault)), 0);
    assertEq(testToken.balanceOf(address(mockStrategy)), depositAmount);

    //Test that the balance view calls work
    assertEq(beefyERC4626.totalAssets(), depositAmount);
    assertEq(beefyERC4626.balanceOfUnderlying(address(this)), depositAmount);

    //Test that we minted the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public {
    deposit();
    beefyERC4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), depositAmount);
    assertEq(testToken.balanceOf(address(mockVault)), 0);
    assertEq(testToken.balanceOf(address(mockStrategy)), 0);

    // //Test that we burned the correct amount of token
    assertEq(beefyERC4626.balanceOf(address(this)), 0);
  }
}
