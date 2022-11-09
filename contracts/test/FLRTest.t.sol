// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "./config/BaseTest.t.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { FlywheelStaticRewards } from "flywheel-v2/rewards/FlywheelStaticRewards.sol";
import { FuseFlywheelLensRouter, CToken as ICToken } from "fuse-flywheel/FuseFlywheelLensRouter.sol";
import "fuse-flywheel/FuseFlywheelCore.sol";
import "../compound/CTokenInterfaces.sol";

import { CErc20 } from "../compound/CErc20.sol";
import { CErc20 } from "../compound/CErc20.sol";
import { MidasFlywheelLensRouter, IComptroller } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { CErc20Delegator } from "../compound/CErc20Delegator.sol";
import { IERC4626 } from "../compound/IERC4626.sol";
import { RewardsDistributorDelegate } from "../compound/RewardsDistributorDelegate.sol";
import { RewardsDistributorDelegator } from "../compound/RewardsDistributorDelegator.sol";
import { ComptrollerInterface } from "../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../compound/InterestRateModel.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";

contract FLRTest is BaseTest {
  MockERC20 underlyingToken;
  MockERC20 rewardToken;

  CErc20Delegate cErc20Delegate;
  CErc20PluginDelegate cErc20PluginDelegate;
  CErc20 cErc20;

  MidasFlywheelCore fwc;
  MidasFlywheelLensRouter fwlr;

  FuseFlywheelCore[] flywheelsToClaim;
  FlywheelStaticRewards fwsr;

  function testFuseFlywheelLensRouter() public fork(NEON_DEVNET) {
    address mkt = 0xfcA37c71230b5F650C068bC0fC43aC92F9cA9bFD;
    fwc = MidasFlywheelCore(0x4059eDB9647f04aAF82CCEdF270922D1AFbD44ad);
    (uint224 index, uint32 lastUpdatedTimestamp) = fwc.strategyState(ERC20(mkt));

    emit log_named_uint("index", index);
    emit log_named_uint("lastUpdatedTimestamp", lastUpdatedTimestamp);
    emit log_named_uint("block.timestamp", block.timestamp);

    fwsr = FlywheelStaticRewards(0xb4bd9Ec6838BE038C4f965333787b859b7c3F1a2);

    (uint224 rewardsPerSecond, uint32 rewardsEndTimestamp) = fwsr.rewardsInfo(ERC20(mkt));

    vm.prank(address(fwc));
    uint256 accrued = fwsr.getAccruedRewards(ERC20(mkt), lastUpdatedTimestamp);

    emit log_named_uint("accrued", accrued);
    emit log_named_uint("rewardsPerSecond", rewardsPerSecond);
    emit log_named_uint("rewardsEndTimestamp", rewardsEndTimestamp);

    fwlr = new MidasFlywheelLensRouter();
    MidasFlywheelLensRouter.MarketRewardsInfo[] memory ri;

    ri = fwlr.getMarketRewardsInfo(IComptroller(0x8727FA63B01525931688DbaDd3e50f36f25fFD68));
    for (uint256 i = 0; i < ri.length; i++) {
      if (address(ri[i].market) != mkt) {
        emit log("NO REWARDS INFO");
        continue;
      }

      emit log("");
      emit log_named_address("RUNNING FOR MARKET", address(ri[i].market));
      emit log_named_uint("underlyingPrice", ri[i].underlyingPrice);
      for (uint256 j = 0; j < ri[i].rewardsInfo.length; j++) {
        emit log_named_uint("rewardSpeedPerSecondPerToken", ri[i].rewardsInfo[j].rewardSpeedPerSecondPerToken);
        emit log_named_uint("rewardTokenPrice", ri[i].rewardsInfo[j].rewardTokenPrice);
        emit log_named_uint("formattedAPR", ri[i].rewardsInfo[j].formattedAPR);
        emit log_named_address("rewardToken", address(ri[i].rewardsInfo[j].rewardToken));
        // emit log_named_uint("indexAfter", ri[i].rewardsInfo[j].indexAfter);
        // emit log_named_uint("indexBefore", ri[i].rewardsInfo[j].indexBefore);
        emit log_named_uint("lastUpdatedTimestampAfter", ri[i].rewardsInfo[j].lastUpdatedTimestampAfter);
        emit log_named_uint("lastUpdatedTimestampBefore", ri[i].rewardsInfo[j].lastUpdatedTimestampBefore);
      }
    }
  }

  function testFuseFlywheelLensRouterBsc() public fork(BSC_MAINNET) {
    address mkt = 0x159A529c00CD4f91b65C54E77703EDb67B4942e4;
    fwc = MidasFlywheelCore(0x379cdA8eCaC6FFE1E8b8D71649ced26B3FA597Ec);
    (uint224 index, uint32 lastUpdatedTimestamp) = fwc.strategyState(ERC20(mkt));

    emit log_named_uint("index", index);
    emit log_named_uint("lastUpdatedTimestamp", lastUpdatedTimestamp);
    emit log_named_uint("block.timestamp", block.timestamp);

    fwsr = FlywheelStaticRewards(0x2207AfAD110133BB1B869F66b42D76910328AEBE);

    (uint224 rewardsPerSecond, uint32 rewardsEndTimestamp) = fwsr.rewardsInfo(ERC20(mkt));

    vm.prank(address(fwc));
    uint256 accrued = fwsr.getAccruedRewards(ERC20(mkt), lastUpdatedTimestamp);

    emit log_named_uint("accrued", accrued);
    emit log_named_uint("rewardsPerSecond", rewardsPerSecond);
    emit log_named_uint("rewardsEndTimestamp", rewardsEndTimestamp);

    fwlr = new MidasFlywheelLensRouter();
    MidasFlywheelLensRouter.MarketRewardsInfo[] memory ri;

    ri = fwlr.getMarketRewardsInfo(IComptroller(0x5EB884651F50abc72648447dCeabF2db091e4117));
    for (uint256 i = 0; i < ri.length; i++) {
      if (address(ri[i].market) != mkt) {
        emit log("NO REWARDS INFO");
        continue;
      }

      emit log("");
      emit log_named_address("RUNNING FOR MARKET", address(ri[i].market));
      emit log_named_uint("underlyingPrice", ri[i].underlyingPrice);
      for (uint256 j = 0; j < ri[i].rewardsInfo.length; j++) {
        emit log_named_uint("rewardSpeedPerSecondPerToken", ri[i].rewardsInfo[j].rewardSpeedPerSecondPerToken);
        emit log_named_uint("rewardTokenPrice", ri[i].rewardsInfo[j].rewardTokenPrice);
        emit log_named_uint("formattedAPR", ri[i].rewardsInfo[j].formattedAPR);
        emit log_named_address("rewardToken", address(ri[i].rewardsInfo[j].rewardToken));
        // emit log_named_uint("indexAfter", ri[i].rewardsInfo[j].indexAfter);
        // emit log_named_uint("indexBefore", ri[i].rewardsInfo[j].indexBefore);
        emit log_named_uint("lastUpdatedTimestampAfter", ri[i].rewardsInfo[j].lastUpdatedTimestampAfter);
        emit log_named_uint("lastUpdatedTimestampBefore", ri[i].rewardsInfo[j].lastUpdatedTimestampBefore);
      }
    }
  }

  function testFetchPluginAddress() public fork(BSC_MAINNET) {
    cErc20PluginDelegate = CErc20PluginDelegate(0x383158Db17719d2Cf1Ce10Ccb9a6Dd7cC1f54EF3);
    IERC4626 plugin = cErc20PluginDelegate.plugin();
    emit log_named_address("plugin", address(plugin));
    assertEq(address(plugin), 0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE);
  }
}
