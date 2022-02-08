// SPDX-License-Identifier: UNLICENSED

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import "../contracts/compound/strategies/BeefyERC4626.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract BeefyERC4626Test is DSTest {
  using stdStorage for StdStorage;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  StdStorage stdstore;

  BeefyERC4626 beefyERC4626;

  function setUp() public {
    beefyERC4626 = new BeefyERC4626(
      ERC20(0x0000000000000000000000000000000000000000),
      "test",
      "test",
      IBeefyVault(0x0000000000000000000000000000000000000000)
    );
  }

  function testName() public {
    assertEq(beefyERC4626.name(), "test");
  }

  function deposit() public {}
}
