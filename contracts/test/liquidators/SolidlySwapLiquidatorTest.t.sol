// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";
import { SolidlySwapLiquidator } from "../../liquidators/SolidlySwapLiquidator.sol";
import "../../external/solidly/IRouter.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract SolidlySwapLiquidatorTest is BaseTest {
  SolidlySwapLiquidator public liquidator;

  function afterForkSetUp() internal override {
    liquidator = new SolidlySwapLiquidator();
  }

  function testSolidlySwapLiquidator() public fork(BSC_MAINNET) {
    IRouter solidlyRouter = IRouter(0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109);
    address ankrBnb = 0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827; // token1
    address hay = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5; // token0
    address ankrBnbWhale = 0x366B523317Cc95B1a4D30b33f8637882825C5E23;
    address hayWhale = 0x0966602E47F6a3CA5692529F1D54EcD1d9B09175;

    IERC20Upgradeable ankrBnbToken = IERC20Upgradeable(ankrBnb);
    IERC20Upgradeable hayToken = IERC20Upgradeable(hay);
    vm.prank(hayWhale);
    hayToken.transfer(address(liquidator), 1e18);

    liquidator.redeem(IERC20Upgradeable(hay), 1e18, abi.encode(solidlyRouter, ankrBnb, false));

    uint256 swappedAmount = ankrBnbToken.balanceOf(address(liquidator));
    assertGt(swappedAmount, 0, "!swapped");
  }
}
