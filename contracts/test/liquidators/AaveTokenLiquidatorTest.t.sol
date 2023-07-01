// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";
import "../../liquidators/AaveTokenLiquidator.sol";

contract AaveTokenLiquidatorTest is BaseTest {
  AaveTokenLiquidator public liquidator;
  address stable;
  address amUsdc = 0x1a13F4Ca1d028320A707D99520AbFefca3998b7F;
  uint256 inputAmount = 1e18;

  function afterForkSetUp() internal override {
    liquidator = new AaveTokenLiquidator();
    stable = ap.getAddress("stableToken");
  }

  function testAmUsdcPolygon() public fork(POLYGON_MAINNET) {
    address amUsdcWhale = 0xe52F5349153b8eb3B89675AF45aC7502C4997E6A; // curve pool
    inputAmount = 1000e6;

    IERC20Upgradeable amUsdcToken = IERC20Upgradeable(amUsdc);
    vm.prank(amUsdcWhale);
    amUsdcToken.transfer(address(liquidator), inputAmount);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      amUsdcToken,
      inputAmount,
      abi.encode(stable)
    );

    assertEq(address(outputToken), stable, "!usdc output");
    assertApproxEqRel(outputAmount, inputAmount, 8e16, "!wbnb amount");
  }
}
