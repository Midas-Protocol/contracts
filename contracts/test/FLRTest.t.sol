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
import { FuseFlywheelCore } from "fuse-flywheel/FuseFlywheelCore.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";

import "../compound/CTokenInterfaces.sol";

import { CErc20 } from "../compound/CErc20.sol";
import { MidasFlywheelLensRouter, IComptroller } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";
import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
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

interface IPriceOracle {
  function price(address underlying) external view returns (uint256);
}

contract FLRTest is BaseTest {
  address rewardToken;

  CErc20Delegate cErc20Delegate;
  CErc20PluginDelegate cErc20PluginDelegate;
  CErc20 cErc20;

  MidasFlywheel flywheel;
  FlywheelStaticRewards rewards;
  MidasFlywheelLensRouter lensRouter;

  FuseFlywheelCore[] flywheelsToClaim;

  address BSC_ADMIN = address(0x82eDcFe00bd0ce1f3aB968aF09d04266Bc092e0E);

  function setUpFlywheel(
    address _rewardToken,
    address mkt,
    IComptroller comptroller,
    address admin
  ) public {
    flywheel = new MidasFlywheel();
    flywheel.initialize(
      ERC20(_rewardToken),
      FlywheelStaticRewards(address(0)),
      IFlywheelBooster(address(0)),
      address(this)
    );

    rewards = new FlywheelStaticRewards(FuseFlywheelCore(address(flywheel)), address(this), Authority(address(0)));
    flywheel.setFlywheelRewards(rewards);

    lensRouter = new MidasFlywheelLensRouter();

    flywheel.addStrategyForRewards(ERC20(mkt));

    // add flywheel as rewardsDistributor to call flywheelPreBorrowAction / flywheelPreSupplyAction
    vm.prank(admin);
    require(comptroller._addRewardsDistributor(address(flywheel)) == 0);

    // seed rewards to flywheel
    deal(_rewardToken, address(rewards), 1_000_000 * (10**ERC20(_rewardToken).decimals()));

    // Start reward distribution at 1 token per second
    rewards.setRewardsInfo(
      ERC20(mkt),
      FlywheelStaticRewards.RewardsInfo({
        rewardsPerSecond: uint224(789 * 10**ERC20(_rewardToken).decimals()),
        rewardsEndTimestamp: 0
      })
    );
  }

  function testFuseFlywheelLensRouterBsc() public fork(BSC_MAINNET) {
    rewardToken = address(0x71be881e9C5d4465B3FfF61e89c6f3651E69B5bb); // BRZ
    emit log_named_address("rewardToken", address(rewardToken));
    address mkt = 0x159A529c00CD4f91b65C54E77703EDb67B4942e4;
    setUpFlywheel(rewardToken, mkt, IComptroller(0x5EB884651F50abc72648447dCeabF2db091e4117), BSC_ADMIN);
    emit log_named_uint("mkt dec", ERC20(mkt).decimals());

    (uint224 index, uint32 lastUpdatedTimestamp) = flywheel.strategyState(ERC20(mkt));

    emit log_named_uint("index", index);
    emit log_named_uint("lastUpdatedTimestamp", lastUpdatedTimestamp);
    emit log_named_uint("block.timestamp", block.timestamp);
    emit log_named_uint(
      "underlying price",
      IPriceOracle(address(IComptroller(0x5EB884651F50abc72648447dCeabF2db091e4117).oracle())).price(
        address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)
      )
    );
    emit log_named_uint("exchangeRateCurrent", CErc20(mkt).exchangeRateCurrent());

    vm.warp(block.timestamp + 10);

    (uint224 rewardsPerSecond, uint32 rewardsEndTimestamp) = rewards.rewardsInfo(ERC20(mkt));

    vm.prank(address(flywheel));
    uint256 accrued = rewards.getAccruedRewards(ERC20(mkt), lastUpdatedTimestamp);

    emit log_named_uint("accrued", accrued);
    emit log_named_uint("rewardsPerSecond", rewardsPerSecond);
    emit log_named_uint("rewardsEndTimestamp", rewardsEndTimestamp);
    emit log_named_uint("mkt ts", ERC20(mkt).totalSupply());

    MidasFlywheelLensRouter.MarketRewardsInfo[] memory marketRewardsInfos = lensRouter.getMarketRewardsInfo(
      IComptroller(0x5EB884651F50abc72648447dCeabF2db091e4117)
    );
    for (uint256 i = 0; i < marketRewardsInfos.length; i++) {
      if (address(marketRewardsInfos[i].market) != mkt) {
        emit log("NO REWARDS INFO");
        continue;
      }

      emit log("");
      emit log_named_address("RUNNING FOR MARKET", address(marketRewardsInfos[i].market));
      for (uint256 j = 0; j < marketRewardsInfos[i].rewardsInfo.length; j++) {
        emit log_named_uint(
          "rewardSpeedPerSecondPerToken",
          marketRewardsInfos[i].rewardsInfo[j].rewardSpeedPerSecondPerToken
        );
        emit log_named_uint("rewardTokenPrice", marketRewardsInfos[i].rewardsInfo[j].rewardTokenPrice);
        emit log_named_uint("formattedAPR", marketRewardsInfos[i].rewardsInfo[j].formattedAPR);
        emit log_named_address("rewardToken", address(marketRewardsInfos[i].rewardsInfo[j].rewardToken));
      }
    }
  }
}
