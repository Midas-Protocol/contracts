// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";
import "../../liquidators/AlgebraSwapLiquidator.sol";

contract AlgebraSwapLiquidatorTest is BaseTest {
  AlgebraSwapLiquidator public liquidator;
  address algebraSwapRouter = 0x327Dd3208f0bCF590A66110aCB6e5e6941A4EfA0;
  address ankrBnbAddress = 0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827;
  address wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  uint256 inputAmount = 1e18;

  function afterForkSetUp() internal override {
    liquidator = new AlgebraSwapLiquidator();
  }

  function testAlgebraAnkrBnbWbnb() public fork(BSC_MAINNET) {
    address ankrBnbWhale = 0x366B523317Cc95B1a4D30b33f8637882825C5E23;

    IERC20Upgradeable ankr = IERC20Upgradeable(ankrBnbAddress);
    vm.prank(ankrBnbWhale);
    ankr.transfer(address(liquidator), 1e18);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      ankr,
      inputAmount,
      abi.encode(wbnbAddress, algebraSwapRouter)
    );

    assertEq(address(outputToken), wbnbAddress, "!wbnb output");
    assertApproxEqRel(outputAmount, inputAmount, 8e16, "!wbnb amount");
  }

  function testAlgebraWbnbAnkrBnb() public fork(BSC_MAINNET) {
    address wbnbWhale = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;

    IERC20Upgradeable wbnb = IERC20Upgradeable(wbnbAddress);
    vm.prank(wbnbWhale);
    wbnb.transfer(address(liquidator), 1e18);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      wbnb,
      inputAmount,
      abi.encode(ankrBnbAddress, algebraSwapRouter)
    );

    assertEq(address(outputToken), ankrBnbAddress, "!ankrbnb output");
    assertApproxEqRel(outputAmount, inputAmount, 8e16, "!ankrbnb amount");
  }
}
