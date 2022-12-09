// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { ComptrollerFirstExtension, DiamondExtension } from "../compound/ComptrollerFirstExtension.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { CTokenInterface, CTokenExtensionInterface } from "../compound/CTokenInterfaces.sol";

import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract ComptrollerTest is BaseTest {
  Comptroller internal comptroller;
  MidasFlywheel internal flywheel;
  address internal nonOwner = address(0x2222);

  event Failure(uint256 error, uint256 info, uint256 detail);

  function setUp() public {
    ERC20 rewardToken = new MockERC20("RewardToken", "RT", 18);
    flywheel = new MidasFlywheel();
    comptroller = new Comptroller(payable(address(this)));
    flywheel.initialize(rewardToken, IFlywheelRewards(address(2)), IFlywheelBooster(address(3)), address(this));
  }

  function test__setFlywheel() external {
    comptroller._addRewardsDistributor(address(flywheel));

    assertEq(comptroller.rewardsDistributors(0), address(flywheel));
  }

  function test__setFlywheelRevertsIfNonOwner() external {
    vm.startPrank(nonOwner);
    vm.expectEmit(false, false, false, true, address(comptroller));
    emit Failure(1, 2, 0);
    comptroller._addRewardsDistributor(address(flywheel));
  }

  function upgradePool(Comptroller pool) internal {
    FuseFeeDistributor ffd = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
    Comptroller newComptrollerImplementation = new Comptroller(payable(ffd));

    Unitroller asUnitroller = Unitroller(payable(address(pool)));
    address oldComptrollerImplementation = asUnitroller.comptrollerImplementation();

    // whitelist the upgrade
    vm.startPrank(ffd.owner());
    ffd._editComptrollerImplementationWhitelist(
      asArray(oldComptrollerImplementation),
      asArray(address(newComptrollerImplementation)),
      asArray(true)
    );
    DiamondExtension[] memory extensions = new DiamondExtension[](1);
    extensions[0] = new ComptrollerFirstExtension();
    ffd._setComptrollerExtensions(address(newComptrollerImplementation), extensions);

    // upgrade to the new comptroller
    // vm.startPrank(asUnitroller.admin());
    asUnitroller._setPendingImplementation(address(newComptrollerImplementation));
    newComptrollerImplementation._become(asUnitroller);
    vm.stopPrank();
  }

  function testTotalBorrowCapPerCollateral() public forkAtBlock(BSC_MAINNET, 23761190) {
    address payable jFiatPoolAddress = payable(0x31d76A64Bc8BbEffb601fac5884372DEF910F044);

    address poolAddress = jFiatPoolAddress;
    Comptroller pool = Comptroller(poolAddress);
    upgradePool(pool);

    address[] memory borrowers = pool.getAllBorrowers();
    address someBorrower = borrowers[1];

    CTokenInterface[] memory markets = pool.getAllMarkets();
    for (uint256 i = 0; i < markets.length; i++) {
      CTokenInterface market = markets[i];
      uint256 borrowed = market.borrowBalanceStored(someBorrower);
      if (borrowed > 0) {
        emit log("borrower has borrowed");
        emit log_uint(borrowed);
        emit log("from market");
        emit log_address(address(market));
        emit log_uint(i);
        emit log("");
      }

      uint256 collateral = market.asCTokenExtensionInterface().balanceOf(someBorrower);
      if (collateral > 0) {
        emit log("has collateral");
        emit log_uint(collateral);
        emit log("in market");
        emit log_address(address(market));
        emit log_uint(i);
        emit log("");
      }
    }

    CTokenInterface marketToBorrow = markets[0];
    CTokenInterface cappedCollateralMarket = markets[6];
    uint256 borrowAmount = marketToBorrow.borrowBalanceStored(someBorrower);

    {
      (uint256 errBefore, uint256 liquidityBefore, uint256 shortfallBefore) = pool.getHypotheticalAccountLiquidity(
        someBorrower,
        address(marketToBorrow),
        0,
        borrowAmount
      );
      emit log("errBefore");
      emit log_uint(errBefore);
      emit log("liquidityBefore");
      emit log_uint(liquidityBefore);
      emit log("shortfallBefore");
      emit log_uint(shortfallBefore);

      assertGt(liquidityBefore, 0, "expected positive liquidity");
    }

    ComptrollerFirstExtension asExtension = ComptrollerFirstExtension(poolAddress);
    vm.prank(pool.admin());
    asExtension._setTotalBorrowCapForAssetForCollateral(address(marketToBorrow), address(cappedCollateralMarket), 1);
    emit log("");

    (uint256 errAfter, uint256 liquidityAfter, uint256 shortfallAfter) = pool.getHypotheticalAccountLiquidity(
      someBorrower,
      address(marketToBorrow),
      0,
      borrowAmount
    );
    emit log("errAfter");
    emit log_uint(errAfter);
    emit log("liquidityAfter");
    emit log_uint(liquidityAfter);
    emit log("shortfallAfter");
    emit log_uint(shortfallAfter);

    assertGt(shortfallAfter, 0, "expected some shortfall");
  }
}
