// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import { FlywheelCore, ERC20 } from "../FlywheelCore.sol";
import { IComptroller } from "../../external/compound/IComptroller.sol";
import { BasePriceOracle } from "../../oracles/BasePriceOracle.sol";
import { IRewardsDistributor } from "../../external/compound/IRewardsDistributor.sol";
import { ICToken } from "../../external/compound/ICToken.sol";

abstract contract CToken is ERC20 {
  function plugin() external view virtual returns (Plugin);
}

interface Plugin {
  function claimRewards() external;
}

contract FuseFlywheelLensRouter {
  function getUnclaimedRewardsForMarket(
    address user,
    CToken market,
    FlywheelCore[] calldata flywheels,
    bool[] calldata accrue,
    bool claimPlugin
  ) external returns (uint256[] memory rewards) {
    uint256 size = flywheels.length;
    rewards = new uint256[](size);

    if (claimPlugin) {
      market.plugin().claimRewards();
    }

    for (uint256 i = 0; i < size; i++) {
      if (accrue[i]) {
        rewards[i] = flywheels[i].accrue(market, user);
      } else {
        rewards[i] = flywheels[i].rewardsAccrued(user);
      }

      flywheels[i].claimRewards(user);
    }
  }

  function getUnclaimedRewardsByMarkets(
    address user,
    CToken[] calldata markets,
    FlywheelCore[] calldata flywheels,
    bool[] calldata accrue,
    bool[] calldata claimPlugins
  ) external returns (uint256[] memory rewards) {
    rewards = new uint256[](flywheels.length);

    for (uint256 i = 0; i < flywheels.length; i++) {
      for (uint256 j = 0; j < markets.length; j++) {
        CToken market = markets[j];
        if (claimPlugins[j]) {
          market.plugin().claimRewards();
        }

        // Overwrite, because rewards are cumulative
        if (accrue[i]) {
          rewards[i] = flywheels[i].accrue(market, user);
        } else {
          rewards[i] = flywheels[i].rewardsAccrued(user);
        }
      }

      flywheels[i].claimRewards(user);
    }
  }

  struct MarketRewardsInfo {
    /// @dev comptroller oracle price of market underlying
    uint256 underlyingPrice;
    ICToken market;
    RewardsInfo[] rewardsInfo;
  }

  struct RewardsInfo {
    /// @dev rewards in `rewardToken` paid per underlying staked token in `market` per second
    uint256 rewardSpeedPerSecondPerToken;
    /// @dev comptroller oracle price of reward token
    uint256 rewardTokenPrice;
    /// @dev APR scaled by 1e18. Calculated as rewardSpeedPerSecondPerToken * rewardTokenPrice * 365.25 days / underlyingPrice * 1e18 / market.exchangeRateCurrent()
    uint256 formattedAPR;
    address flywheel;
    address rewardToken;
  }

  function getMarketRewardsInfo(IComptroller comptroller) external returns (MarketRewardsInfo[] memory) {
    ICToken[] memory markets = comptroller.getAllMarkets();
    IRewardsDistributor[] memory flywheels = comptroller.getRewardsDistributors();
    address[] memory rewardTokens = new address[](flywheels.length);
    uint256[] memory rewardTokenPrices = new uint256[](flywheels.length);
    BasePriceOracle oracle = BasePriceOracle(address(comptroller.oracle()));

    MarketRewardsInfo[] memory infoList = new MarketRewardsInfo[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      RewardsInfo[] memory rewardsInfo = new RewardsInfo[](flywheels.length);

      ICToken market = markets[i];
      // TODO remove this T1->address->T2 casting
      ERC20 strategy = ERC20(address(market));
      uint256 price = oracle.getUnderlyingPrice(market);

      for (uint256 j = 0; j < flywheels.length; j++) {
        // TODO remove this T1->address->T2 casting
        FlywheelCore flywheel = FlywheelCore(address(flywheels[j]));
        if (i == 0) {
          address rewardToken = address(flywheel.rewardToken());
          rewardTokens[j] = rewardToken;
          rewardTokenPrices[j] = oracle.price(rewardToken);
        }
        uint256 rewardSpeedPerSecondPerToken;
        {
          (uint224 indexBefore, uint32 lastUpdatedTimestampBefore) = flywheel.strategyState(strategy);
          flywheel.accrue(strategy, address(0));
          (uint224 indexAfter, uint32 lastUpdatedTimestampAfter) = flywheel.strategyState(strategy);
          if (lastUpdatedTimestampAfter > lastUpdatedTimestampBefore) {
            rewardSpeedPerSecondPerToken =
              (indexAfter - indexBefore) /
              (lastUpdatedTimestampAfter - lastUpdatedTimestampBefore);
          }
        }
        rewardsInfo[j] = RewardsInfo({
          rewardSpeedPerSecondPerToken: rewardSpeedPerSecondPerToken,
          rewardTokenPrice: rewardTokenPrices[j],
          formattedAPR: (((rewardSpeedPerSecondPerToken * rewardTokenPrices[j] * 365.25 days) / price) * 1e18) /
            market.exchangeRateCurrent(),
          flywheel: address(flywheel),
          rewardToken: rewardTokens[j]
        });
      }

      infoList[i] = MarketRewardsInfo({ market: market, rewardsInfo: rewardsInfo, underlyingPrice: price });
    }

    return infoList;
  }
}
