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
    ffd = new FuseFeeDistributor();
    ffd.initialize(0);
    ffd._setPoolLimits(100e18, 0, 0);
  }

  function testMinBorrow() public fork(BSC_MAINNET) {
    MockERC20 asset = MockERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);

    CErc20Interface cToken = CErc20Interface(0x216714Ecf4FEcc35573CBB2756942274E1B344A2);
    ComptrollerInterface comptroller = cToken.comptroller();
    deal(address(asset), address(this), 1000e18);

    asset.approve(address(cToken), 1e36);
    cToken.mint(100e18);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);

    uint256 minBorrowEth = ffd.getMinBorrowEth(cToken);

    assertEq(minBorrowEth, 100e18, "!minBorrowEth for default min borrow eth");
    cToken.borrow(1e18);

    minBorrowEth = ffd.getMinBorrowEth(cToken);
    assertLt(minBorrowEth, 100e18, "!minBorrowEth after borrowing less amount than min amount");

    cToken.borrow(2e18);

    minBorrowEth = ffd.getMinBorrowEth(cToken);
    assertEq(minBorrowEth, 0, "!minBorrowEth after borrowing great amount than min amount");
  }
}
