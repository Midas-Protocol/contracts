// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { IComptroller } from "../compound/ComptrollerInterface.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";

import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ComptrollerErrorReporter } from "../compound/ErrorReporter.sol";

contract ComptrollerTest is BaseTest {
  IComptroller internal comptroller;
  MidasFlywheel internal flywheel;
  address internal nonOwner = address(0x2222);

  event Failure(uint256 error, uint256 info, uint256 detail);

  function setUp() public {
    ERC20 rewardToken = new MockERC20("RewardToken", "RT", 18);
    comptroller = IComptroller(address(new Comptroller(payable(address(this)))));
    MidasFlywheel impl = new MidasFlywheel();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(dpa), "");
    flywheel = MidasFlywheel(address(proxy));
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

  function testBscInflationProtection() public debuggingOnly fork(BSC_MAINNET) {
    _testInflationProtection();
  }

  function testPolygonInflationProtection() public debuggingOnly fork(POLYGON_MAINNET) {
    _testInflationProtection();
  }

  function testMoonbeamInflationProtection() public debuggingOnly fork(MOONBEAM_MAINNET) {
    _testInflationProtection();
  }

  function testEvmosInflationProtection() public debuggingOnly fork(EVMOS_MAINNET) {
    _testInflationProtection();
  }

  function testFantomInflationProtection() public debuggingOnly fork(FANTOM_OPERA) {
    _testInflationProtection();
  }

  function _testInflationProtection() internal {
    FusePoolDirectory fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();
    for (uint256 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);
      ICErc20[] memory markets = pool.getAllMarkets();
      for (uint256 j = 0; j < markets.length; j++) {
        ICErc20 market = markets[j];
        uint256 totalSupply = market.totalSupply();
        if (totalSupply > 0) {
          if (totalSupply < 1000) {
            emit log_named_address("low ts market", address(markets[j]));
            emit log_named_uint("ts", totalSupply);
          } else {
            assertEq(
              pool.redeemAllowed(address(markets[j]), address(0), totalSupply - 980),
              uint256(ComptrollerErrorReporter.Error.REJECTION),
              "low ts not rejected"
            );
          }
        }
      }
    }
  }
}
