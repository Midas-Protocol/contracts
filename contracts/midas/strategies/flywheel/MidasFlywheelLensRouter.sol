// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MidasFlywheelCore } from "./MidasFlywheelCore.sol";

abstract contract CErc20Token is ERC20 {
  function exchangeRateCurrent() external virtual returns (uint256);

  function underlying() external view virtual returns (address);
}

interface IPriceOracle {
  function getUnderlyingPrice(CErc20Token cToken) external view returns (uint256);

  function price(address underlying) external view returns (uint256);
}

interface IComptroller {
  function getRewardsDistributors() external view returns (MidasFlywheelCore[] memory);

  function getAllMarkets() external view returns (CErc20Token[] memory);

  function oracle() external view returns (IPriceOracle);

  function admin() external returns (address);

  function _addRewardsDistributor(address distributor) external returns (uint256);
}

contract MidasFlywheelLensRouter {
  struct MarketRewardsInfo {
    /// @dev comptroller oracle price of market underlying
    uint256 underlyingPrice;
    CErc20Token market;
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
    CErc20Token[] memory markets = comptroller.getAllMarkets();
    MidasFlywheelCore[] memory flywheels = comptroller.getRewardsDistributors();
    address[] memory rewardTokens = new address[](flywheels.length);
    uint256[] memory rewardTokenPrices = new uint256[](flywheels.length);
    IPriceOracle oracle = comptroller.oracle();

    MarketRewardsInfo[] memory infoList = new MarketRewardsInfo[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      RewardsInfo[] memory rewardsInfo = new RewardsInfo[](flywheels.length);

      CErc20Token market = markets[i];
      uint256 price = oracle.price(market.underlying()); // scaled to 1e18

      for (uint256 j = 0; j < flywheels.length; j++) {
        MidasFlywheelCore flywheel = flywheels[j];
        if (i == 0) {
          address rewardToken = address(flywheel.rewardToken());
          rewardTokens[j] = rewardToken;
          rewardTokenPrices[j] = oracle.price(rewardToken); // scaled to 1e18
        }
        uint256 rewardSpeedPerSecondPerToken;
        {
          (uint224 indexBefore, uint32 lastUpdatedTimestampBefore) = flywheel.strategyState(market);
          flywheel.accrue(market, address(0));
          (uint224 indexAfter, uint32 lastUpdatedTimestampAfter) = flywheel.strategyState(market);
          if (lastUpdatedTimestampAfter > lastUpdatedTimestampBefore) {
            rewardSpeedPerSecondPerToken =
              (indexAfter - indexBefore) /
              (lastUpdatedTimestampAfter - lastUpdatedTimestampBefore);
          }
        }

        uint256 aprInRewardsTokenDecimals = getAprInRewardsTokenDecimals(
          rewardSpeedPerSecondPerToken,
          rewardTokenPrices[j],
          price,
          market.exchangeRateCurrent()
        );

        rewardsInfo[j] = RewardsInfo({
          rewardSpeedPerSecondPerToken: rewardSpeedPerSecondPerToken,
          rewardTokenPrice: rewardTokenPrices[j],
          formattedAPR: (aprInRewardsTokenDecimals * 1e18) / 10**ERC20(rewardTokens[j]).decimals(),
          flywheel: address(flywheel),
          rewardToken: rewardTokens[j]
        });
      }

      infoList[i] = MarketRewardsInfo({ market: market, rewardsInfo: rewardsInfo, underlyingPrice: price });
    }

    return infoList;
  }

  event log(string);
  event log_uint(uint256);

  function getAprInRewardsTokenDecimals(
    uint256 rewardSpeedPerSecondPerToken,
    uint256 rewardTokenPrice,
    uint256 underlyingPrice,
    uint256 exchangeRate
  ) internal returns (uint256) {
    emit log("");
    emit log("rewardSpeedPerSecondPerToken");
    emit log_uint(rewardSpeedPerSecondPerToken);

    uint256 nativeSpeedPerSecondPerCToken = rewardSpeedPerSecondPerToken * rewardTokenPrice; // scaled to 10^(reward.decimals + 18)
    emit log("nativeSpeedPerSecondPerCToken");
    emit log_uint(nativeSpeedPerSecondPerCToken);

    uint256 nativeSpeedPerYearPerCToken = nativeSpeedPerSecondPerCToken * 365.25 days; // scaled to 10^(reward.decimals + 18)
    emit log("nativeSpeedPerYearPerCToken");
    emit log_uint(nativeSpeedPerYearPerCToken);

    uint256 assetSpeedPerYearPerCToken = nativeSpeedPerYearPerCToken / underlyingPrice; // scaled to 10^(reward.decimals)
    emit log("assetSpeedPerYearPerCToken");
    emit log_uint(assetSpeedPerYearPerCToken);

    uint256 assetSpeedPerYearPerCTokenScaled = assetSpeedPerYearPerCToken * 1e18; // scaled to 10^(reward.decimals + 18)
    emit log("assetSpeedPerYearPerCTokenScaled");
    emit log_uint(assetSpeedPerYearPerCTokenScaled);

    uint256 aprInRewardsTokenDecimals = assetSpeedPerYearPerCTokenScaled / exchangeRate; // scaled to 10^(reward.decimals)
    emit log("aprInRewardsTokenDecimals");
    emit log_uint(aprInRewardsTokenDecimals);

    return aprInRewardsTokenDecimals;
  }

  function getUnclaimedRewardsForMarket(
    address user,
    ERC20 market,
    MidasFlywheelCore[] calldata flywheels,
    bool[] calldata accrue
  ) external returns (uint256[] memory rewards) {
    uint256 size = flywheels.length;
    rewards = new uint256[](size);

    for (uint256 i = 0; i < size; i++) {
      uint256 newRewards;
      if (accrue[i]) {
        newRewards = flywheels[i].accrue(market, user);
      } else {
        newRewards = flywheels[i].rewardsAccrued(user);
      }

      // Take the max, because rewards are cumulative.
      rewards[i] = rewards[i] >= newRewards ? rewards[i] : newRewards;

      flywheels[i].claimRewards(user);
    }
  }

  function getUnclaimedRewardsByMarkets(
    address user,
    CErc20Token[] calldata markets,
    MidasFlywheelCore[] calldata flywheels,
    bool[] calldata accrue
  ) external returns (uint256[] memory rewards) {
    rewards = new uint256[](flywheels.length);

    for (uint256 i = 0; i < flywheels.length; i++) {
      for (uint256 j = 0; j < markets.length; j++) {
        CErc20Token market = markets[j];

        uint256 newRewards;
        if (accrue[i]) {
          newRewards = flywheels[i].accrue(market, user);
        } else {
          newRewards = flywheels[i].rewardsAccrued(user);
        }

        // Take the max, because rewards are cumulative.
        rewards[i] = rewards[i] >= newRewards ? rewards[i] : newRewards;
      }

      flywheels[i].claimRewards(user);
    }
  }
}
