// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ComptrollerInterface, CErc20Interface } from "../compound/CTokenInterfaces.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";

import { BaseTest } from "./config/BaseTest.t.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract MinBorrowTest is BaseTest {
  FuseFeeDistributor ffd;

  function afterForkSetUp() internal override {
    ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
  }

  function testMinBorrow() public fork(BSC_MAINNET) {
    MockERC20 asset = MockERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    MockERC20 asset1 = MockERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    CErc20Interface cToken = CErc20Interface(0x71661c706deEA398F3Cca3187cFB4b6576bDc0f6);
    CErc20Interface cToken1 = CErc20Interface(0x2F01b89614b963401879b325f853D553375faB58);
    ComptrollerInterface comptroller = cToken.comptroller();
    deal(address(asset), address(this), 10000e18);
    deal(address(asset1), address(1), 10000e18);

    asset.approve(address(cToken), 1e36);
    cToken.mint(1000e18);

    vm.startPrank(address(1));
    asset1.approve(address(cToken1), 1e36);
    cToken1.mint(1000e18);
    vm.stopPrank();

    address[] memory cTokens = new address[](2);
    cTokens[0] = address(cToken);
    cTokens[1] = address(cToken1);
    comptroller.enterMarkets(cTokens);

    uint256 minBorrowEth = ffd.getMinBorrowEth(cToken1);

    assertEq(minBorrowEth, 1e18, "!minBorrowEth for default min borrow eth");
    cToken1.borrow(300e18);

    minBorrowEth = ffd.getMinBorrowEth(cToken1);
    assertEq(minBorrowEth, 0, "!minBorrowEth after borrowing less amount than min amount");
  }
}
