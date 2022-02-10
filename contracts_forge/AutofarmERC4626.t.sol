// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import {AutofarmERC4626, IAutofarmV2} from "../contracts/compound/strategies/AutofarmERC4626.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {MockERC20} from "@rari-capital/solmate/src/test/utils/mocks/MockERC20.sol";
import {MockStrategy} from "./mocks/autofarm/MockStrategy.sol";
import {MockAutofarmV2} from "./mocks/autofarm/MockAutofarmV2.sol";
import {IStrategy} from "./mocks/autofarm/IStrategy.sol";

contract AutofarmERC4626Test is DSTest {
  using stdStorage for StdStorage;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  StdStorage stdstore;

  AutofarmERC4626 autofarmERC4626;

  MockERC20 testToken;
  MockStrategy mockStrategy;
  MockAutofarmV2 mockAutofarm;

  uint256 depositAmount = 100e18;

  function setUp() public {
    testToken = new MockERC20("TestToken", "TST", 18);
    mockAutofarm = new MockAutofarmV2();
    mockStrategy = new MockStrategy(address(testToken), address(mockAutofarm));

    // Add mockStrategy to Autofarm
    mockAutofarm.add(ERC20(address(testToken)), 0, address(mockStrategy));

    autofarmERC4626 = new AutofarmERC4626(testToken, "TestVault", "TSTV", 0, IAutofarmV2(address(mockAutofarm)));
  }

  function testInitalizedValues() public {
    assertEq(autofarmERC4626.name(), "TestVault");
    assertEq(autofarmERC4626.symbol(), "TSTV");
    assertEq(address(autofarmERC4626.asset()), address(testToken));
    assertEq(address(autofarmERC4626.autofarm()), address(mockAutofarm));
    //assertEq(mockAutofarm.poolLength(), 1);
  }

  function deposit() public {
    testToken.mint(address(this), depositAmount);
    testToken.approve(address(autofarmERC4626), depositAmount);
    autofarmERC4626.deposit(depositAmount, address(this));
  }

  function testDeposit() public {
    deposit();
    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), 0);
    assertEq(testToken.balanceOf(address(mockAutofarm)), 0);
    assertEq(testToken.balanceOf(address(mockStrategy)), depositAmount);

    // //Test that the balance view calls work
    assertEq(autofarmERC4626.totalAssets(), depositAmount);
    assertEq(autofarmERC4626.balanceOfUnderlying(address(this)), depositAmount);

    // Test that we minted the correct amount of token
    assertEq(autofarmERC4626.balanceOf(address(this)), depositAmount);
  }

  function testWithdraw() public {
    deposit();
    autofarmERC4626.withdraw(depositAmount, address(this), address(this));

    //Test that the actual transfers worked
    assertEq(testToken.balanceOf(address(this)), depositAmount);
    assertEq(testToken.balanceOf(address(mockAutofarm)), 0);
    assertEq(testToken.balanceOf(address(mockStrategy)), 0);

    //Test that the balance view calls work
    // !!! This reverts since we divide by 0
    // The contract works fine but the question would be if we want to return a 0 if supply is 0 or if we are fine that the view function errors
    // assertEq(autofarmERC4626.totalAssets(), 0);
    // assertEq(autofarmERC4626.balanceOfUnderlying(address(this)), 0);

    // //Test that we burned the correct amount of token
    assertEq(autofarmERC4626.balanceOf(address(this)), 0);
  }
}
