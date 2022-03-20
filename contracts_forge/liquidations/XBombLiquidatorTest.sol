// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../../contracts/external/bomb/IXBomb.sol";
import "../../contracts/liquidators/XBombLiquidator.sol";

contract XBombLiquidatorTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  IXBomb xbombToken = IXBomb(0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b);
  address underlyingBombTokenAddress = 0x522348779DCb2911539e76A1042aA922F9C47Ee3;

  XBombLiquidator liquidator;

  function setUp() public {
    liquidator = new XBombLiquidator();
  }

  function test() public {
    // the Pancake BOMB/xBOMB pair
    address holder = 0x6aE0Fb5D98911cF5AF6A8CE0AeCE426227d41103;
    // impersonate the holder
    vm.startPrank(holder);

    // make sure we're testing with at least some tokens
    uint256 balance = xbombToken.balanceOf(holder);
    assert(balance > 0);

    // fund the liquidator so it can redeem the tokens
    xbombToken.transfer(address(liquidator), balance);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      IERC20Upgradeable(address(xbombToken)),
      balance,
      ""
    );

    assertEq(address(outputToken), underlyingBombTokenAddress);
    assertEq(outputAmount, xbombToken.toREWARD(balance));
  }
}
