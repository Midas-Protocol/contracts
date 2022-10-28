// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "./helpers/WithPool.sol";
import "./config/BaseTest.t.sol";
import "../compound/CToken.sol";
import "../compound/CTokenInterfaces.sol";
import "../compound/Comptroller.sol";
import "../FuseFeeDistributor.sol";
import "../oracles/default/UniswapTwapPriceOracleV2Resolver.sol";
import "../oracles/default/UniswapTwapPriceOracleV2Root.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract MinBorrowTest is BaseTest {
  FuseFeeDistributor ffd;
  MasterPriceOracle mpo;

  function setUp() public override forkAtBlock(BSC_MAINNET, 20238373) {
    ffd = new FuseFeeDistributor();
    mpo = MasterPriceOracle(0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA);
    ffd.initialize(0);
    ffd._setPoolLimits(100e18, 0, 0);
  }

  function testMinBorrow() public {
    MockERC20 asset = MockERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);

    CErc20Delegate cToken = CErc20Delegate(0x216714Ecf4FEcc35573CBB2756942274E1B344A2);
    Comptroller comptroller = Comptroller(address(cToken.comptroller()));
    deal(address(asset), address(this), 1000e18);

    asset.approve(address(cToken), 1e36);
    cToken.mint(100e18);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);

    uint256 minBorrowEth = ffd.getMinBorrowEth(CTokenInterface(cToken));

    assertEq(minBorrowEth, 100e18, "!minBorrowEth for default min borrow eth");
    cToken.borrow(1e18);

    minBorrowEth = ffd.getMinBorrowEth(CTokenInterface(cToken));
    assertLt(minBorrowEth, 100e18, "!minBorrowEth after borrowing less amount than min amount");

    cToken.borrow(2e18);

    minBorrowEth = ffd.getMinBorrowEth(CTokenInterface(cToken));
    assertEq(minBorrowEth, 0, "!minBorrowEth after borrowing great amount than min amount");
  }
}
