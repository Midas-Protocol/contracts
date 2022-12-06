// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ComptrollerInterface, CErc20Interface } from "../compound/CTokenInterfaces.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";

import { BaseTest } from "./config/BaseTest.t.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract MinBorrowTest is BaseTest {
  FuseFeeDistributor ffd;

  function afterForkSetUp() internal override {
    ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
  }

  function testMinBorrow() public fork(BSC_MAINNET) {
    IERC20Upgradeable usdc = IERC20Upgradeable(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20Upgradeable busd = IERC20Upgradeable(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    CErc20Interface usdcMarket = CErc20Interface(0x71661c706deEA398F3Cca3187cFB4b6576bDc0f6);
    CErc20Interface busdMarket = CErc20Interface(0x2F01b89614b963401879b325f853D553375faB58);
    ComptrollerInterface comptroller = usdcMarket.comptroller();
    deal(address(usdc), address(this), 10000e18);
    deal(address(busd), address(1), 10000e18);

    usdc.approve(address(usdcMarket), 1e36);
    usdcMarket.mint(1000e18);

    vm.startPrank(address(1));
    busd.approve(address(busdMarket), 1e36);
    busdMarket.mint(1000e18);
    vm.stopPrank();

    // the 0 liquidity base min borrow amount
    uint256 baseMinBorrowEth = ffd.minBorrowEth();

    address[] memory cTokens = new address[](2);
    cTokens[0] = address(usdcMarket);
    cTokens[1] = address(busdMarket);
    comptroller.enterMarkets(cTokens);

    uint256 minBorrowEth = ffd.getMinBorrowEth(busdMarket);
    assertEq(minBorrowEth, baseMinBorrowEth, "!minBorrowEth for default min borrow eth");

    busdMarket.borrow(300e18);

    minBorrowEth = ffd.getMinBorrowEth(busdMarket);
    assertEq(minBorrowEth, 0, "!minBorrowEth after borrowing less amount than min amount");
  }
}
