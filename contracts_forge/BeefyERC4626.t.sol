// SPDX-License-Identifier: UNLICENSED

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import "../contracts/compound/strategies/BeefyERC4626.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {MockERC20} from "@rari-capital/solmate/src/test/utils/mocks/MockERC20.sol";

contract BeefyERC4626Test is DSTest {
  using stdStorage for StdStorage;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  StdStorage stdstore;

  BeefyERC4626 beefyERC4626;

  function setUp() public {
    ERC20 test = new MockERC20("test", "TST", 18);
    beefyERC4626 = new BeefyERC4626(
      test,
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
