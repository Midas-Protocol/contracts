// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { UpgradesBaseTest } from "./UpgradesBaseTest.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CTokenFirstExtension } from "../compound/CTokenFirstExtension.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";

struct AccrualDiff {
  uint256 borrowIndex;
  uint256 totalBorrows;
  uint256 totalReserves;
  uint256 totalIonicFees;
  uint256 totalAdminFees;
}

contract AccrueInterestTest is UpgradesBaseTest {
  // fork before the accrue interest refactoring
  function testAccrueInterest() public debuggingOnly forkAtBlock(BSC_MAINNET, 26032460) {
    address busdMarketAddress = 0xa7213deB44f570646Ea955771Cc7f39B58841363;
    address wbnbMarketAddress = 0x57a64a77f8E4cFbFDcd22D5551F52D675cc5A956;

    _testAccrueInterest(wbnbMarketAddress);
  }

  function _testAccrueInterest(address marketAddress) internal {
    //CErc20Delegate market = CErc20Delegate(marketAddress);
    CTokenFirstExtension marketAsExt = CTokenFirstExtension(marketAddress);
    ICErc20 market = ICErc20(marketAddress);

    uint256 adminFeeMantissa = market.adminFeeMantissa();
    uint256 ionicFeeMantissa = market.ionicFeeMantissa();
    uint256 reserveFactorMantissa = market.reserveFactorMantissa();

    // test with the logic before the refactoring

    AccrualDiff memory diffBefore;
    // accrue at the latest block in order to have an equal/comparable accrual period
    marketAsExt.accrueInterest();
    {
      CTokenFirstExtension.InterestAccrual memory accrualDataBefore;
      CTokenFirstExtension.InterestAccrual memory accrualDataAfter;

      accrualDataBefore.accrualBlockNumber = marketAsExt.accrualBlockNumber();
      accrualDataBefore.borrowIndex = marketAsExt.borrowIndex();
      accrualDataBefore.totalBorrows = marketAsExt.totalBorrows();
      accrualDataBefore.totalReserves = marketAsExt.totalReserves();
      accrualDataBefore.totalIonicFees = marketAsExt.totalIonicFees();
      accrualDataBefore.totalAdminFees = marketAsExt.totalAdminFees();
      accrualDataBefore.totalSupply = marketAsExt.totalSupply();

      vm.roll(block.number + 1e6); // move 1M blocks forward
      marketAsExt.accrueInterest();

      accrualDataAfter.accrualBlockNumber = marketAsExt.accrualBlockNumber();
      accrualDataAfter.borrowIndex = marketAsExt.borrowIndex();
      accrualDataAfter.totalBorrows = marketAsExt.totalBorrows();
      accrualDataAfter.totalReserves = marketAsExt.totalReserves();
      accrualDataAfter.totalIonicFees = marketAsExt.totalIonicFees();
      accrualDataAfter.totalAdminFees = marketAsExt.totalAdminFees();
      accrualDataAfter.totalSupply = marketAsExt.totalSupply();

      assertEq(
        accrualDataBefore.accrualBlockNumber,
        accrualDataAfter.accrualBlockNumber - 1e6,
        "!total supply old impl"
      );
      assertLt(accrualDataBefore.borrowIndex, accrualDataAfter.borrowIndex, "!borrow index old impl");
      assertLt(accrualDataBefore.totalBorrows, accrualDataAfter.totalBorrows, "!total borrows old impl");
      if (reserveFactorMantissa > 0) {
        assertLt(accrualDataBefore.totalReserves, accrualDataAfter.totalReserves, "!total reserves old impl");
      }
      if (ionicFeeMantissa > 0) {
        assertLt(accrualDataBefore.totalIonicFees, accrualDataAfter.totalIonicFees, "!total ionic fees old impl");
      }
      if (adminFeeMantissa > 0) {
        assertLt(accrualDataBefore.totalAdminFees, accrualDataAfter.totalAdminFees, "!total admin fees old impl");
      }
      assertEq(accrualDataBefore.totalSupply, accrualDataAfter.totalSupply, "!total supply old impl");

      diffBefore.borrowIndex = accrualDataAfter.borrowIndex - accrualDataBefore.borrowIndex;
      diffBefore.totalBorrows = accrualDataAfter.totalBorrows - accrualDataBefore.totalBorrows;
      diffBefore.totalReserves = accrualDataAfter.totalReserves - accrualDataBefore.totalReserves;
      diffBefore.totalIonicFees = accrualDataAfter.totalIonicFees - accrualDataBefore.totalIonicFees;
      diffBefore.totalAdminFees = accrualDataAfter.totalAdminFees - accrualDataBefore.totalAdminFees;
    }

    // test with the logic after the refactoring
    vm.rollFork(26032460);
    afterForkSetUp();
    _upgradeMarketWithExtension(market);

    AccrualDiff memory diffAfter;
    // accrue at the latest block in order to have an equal/comparable accrual period
    marketAsExt.accrueInterest();
    {
      CTokenFirstExtension.InterestAccrual memory accrualDataBefore;
      CTokenFirstExtension.InterestAccrual memory accrualDataAfter;

      accrualDataBefore.accrualBlockNumber = marketAsExt.accrualBlockNumber();
      accrualDataBefore.borrowIndex = marketAsExt.borrowIndex();
      accrualDataBefore.totalBorrows = marketAsExt.totalBorrows();
      accrualDataBefore.totalReserves = marketAsExt.totalReserves();
      accrualDataBefore.totalIonicFees = marketAsExt.totalIonicFees();
      accrualDataBefore.totalAdminFees = marketAsExt.totalAdminFees();
      accrualDataBefore.totalSupply = marketAsExt.totalSupply();

      vm.roll(block.number + 1e6); // move 1M blocks forward
      marketAsExt.accrueInterest();

      accrualDataAfter.accrualBlockNumber = marketAsExt.accrualBlockNumber();
      accrualDataAfter.borrowIndex = marketAsExt.borrowIndex();
      accrualDataAfter.totalBorrows = marketAsExt.totalBorrows();
      accrualDataAfter.totalReserves = marketAsExt.totalReserves();
      accrualDataAfter.totalIonicFees = marketAsExt.totalIonicFees();
      accrualDataAfter.totalAdminFees = marketAsExt.totalAdminFees();
      accrualDataAfter.totalSupply = marketAsExt.totalSupply();

      assertEq(
        accrualDataBefore.accrualBlockNumber,
        accrualDataAfter.accrualBlockNumber - 1e6,
        "!total supply old impl"
      );
      assertLt(accrualDataBefore.borrowIndex, accrualDataAfter.borrowIndex, "!borrow index new impl");
      assertLt(accrualDataBefore.totalBorrows, accrualDataAfter.totalBorrows, "!total borrows new impl");
      if (reserveFactorMantissa > 0) {
        assertLt(accrualDataBefore.totalReserves, accrualDataAfter.totalReserves, "!total reserves new impl");
      }
      if (ionicFeeMantissa > 0) {
        assertLt(accrualDataBefore.totalIonicFees, accrualDataAfter.totalIonicFees, "!total ionic fees new impl");
      }
      if (adminFeeMantissa > 0) {
        assertLt(accrualDataBefore.totalAdminFees, accrualDataAfter.totalAdminFees, "!total admin fees new impl");
      }
      assertEq(accrualDataBefore.totalSupply, accrualDataAfter.totalSupply, "!total supply new impl");

      diffAfter.borrowIndex = accrualDataAfter.borrowIndex - accrualDataBefore.borrowIndex;
      diffAfter.totalBorrows = accrualDataAfter.totalBorrows - accrualDataBefore.totalBorrows;
      diffAfter.totalReserves = accrualDataAfter.totalReserves - accrualDataBefore.totalReserves;
      diffAfter.totalIonicFees = accrualDataAfter.totalIonicFees - accrualDataBefore.totalIonicFees;
      diffAfter.totalAdminFees = accrualDataAfter.totalAdminFees - accrualDataBefore.totalAdminFees;
    }

    assertEq(diffBefore.borrowIndex, diffAfter.borrowIndex, "!borrowIndexDiff");
    assertEq(diffBefore.totalBorrows, diffAfter.totalBorrows, "!totalBorrowsDiff");
    assertEq(diffBefore.totalReserves, diffAfter.totalReserves, "!totalReservesDiff");
    assertEq(diffBefore.totalIonicFees, diffAfter.totalIonicFees, "!totalIonicFeesDiff");
    assertEq(diffBefore.totalAdminFees, diffAfter.totalAdminFees, "!totalAdminFeesDiff");
  }

  function _functionCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    (bool success, bytes memory returndata) = target.call(data);

    if (!success) {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }

    return returndata;
  }

  function testExploitFix() public debuggingOnly forkAtBlock(BSC_MAINNET, 29185768) {
    // run a market upgrade just before the exploiting tx is called
    address hayBusdMarket = 0xF8527Dc5611B589CbB365aCACaac0d1DC70b25cB;
    _upgradeMarketWithExtension(ICErc20(hayBusdMarket));

    vm.prank(0x4b92cC3452Ef1E37528470495B86d3F976470734);
    _functionCall(0xC40119C7269A5FA813d878BF83d14E3462fC8Fde, hex"8f93bfba", "raw liquidation failed");
  }
}
