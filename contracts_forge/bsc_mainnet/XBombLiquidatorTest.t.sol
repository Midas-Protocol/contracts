// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../contracts/external/bomb/IXBomb.sol";
import "../../contracts/liquidators/XBombLiquidator.sol";
import { BscMainnetBaseTest } from "../config/BaseTest.t.sol";

contract XBombLiquidatorTest is BscMainnetBaseTest {
  // the Pancake BOMB/xBOMB pair
  address holder = 0x6aE0Fb5D98911cF5AF6A8CE0AeCE426227d41103;
  IXBomb xbombToken = IXBomb(0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b);
  address bombTokenAddress = 0x522348779DCb2911539e76A1042aA922F9C47Ee3; // BOMB

  function setUp() public override {
    super.setUp();
    // impersonate the holder
    vm.startPrank(holder);
  }

  function testRedeem() public {
    XBombLiquidator liquidator = new XBombLiquidator();

    // make sure we're testing with at least some tokens
    uint256 balance = xbombToken.balanceOf(holder);
    assertTrue(balance > 0);

    // fund the liquidator so it can redeem the tokens
    xbombToken.transfer(address(liquidator), balance);
    // redeem the underlying reward token
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      IERC20Upgradeable(address(xbombToken)),
      balance,
      ""
    );

    assertEq(address(outputToken), bombTokenAddress);
    assertEq(outputAmount, xbombToken.toREWARD(balance));
  }
}
