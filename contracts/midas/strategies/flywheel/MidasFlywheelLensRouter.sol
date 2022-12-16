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

  function rewardsDistributors(uint256 index) external view returns (MidasFlywheelCore);

  function getAllMarkets() external view returns (CErc20Token[] memory);

  function oracle() external view returns (IPriceOracle);

  function admin() external returns (address);

  function _addRewardsDistributor(address distributor) external returns (uint256);

  function getAccruingFlywheels() external view returns (MidasFlywheelCore[] memory);
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
    MidasFlywheelCore[] memory flywheels = comptroller.getAccruingFlywheels();
    address[] memory rewardTokens = new address[](flywheels.length);
    uint256[] memory rewardTokenPrices = new uint256[](flywheels.length);
    uint256[] memory rewardTokenDecimals = new uint256[](flywheels.length);
    IPriceOracle oracle = comptroller.oracle();

    MarketRewardsInfo[] memory infoList = new MarketRewardsInfo[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      RewardsInfo[] memory rewardsInfo = new RewardsInfo[](flywheels.length);

      CErc20Token market = markets[i];
      uint256 price = oracle.price(market.underlying()); // scaled to 1e18

      if (i == 0) {
        for (uint256 j = 0; j < flywheels.length; j++) {
          ERC20 rewardToken = flywheels[j].rewardToken();
          rewardTokens[j] = address(rewardToken);
          rewardTokenPrices[j] = oracle.price(address(rewardToken)); // scaled to 1e18
          rewardTokenDecimals[j] = uint256(rewardToken.decimals());
        }
      }

      for (uint256 j = 0; j < flywheels.length; j++) {
        MidasFlywheelCore flywheel = flywheels[j];

        uint256 rewardSpeedPerSecondPerToken = getRewardSpeedPerSecondPerToken(flywheel, market, rewardTokenDecimals[j]);
        uint256 apr = getApr(rewardSpeedPerSecondPerToken, rewardTokenPrices[j], price, market.exchangeRateCurrent());

        rewardsInfo[j] = RewardsInfo({
          rewardSpeedPerSecondPerToken: rewardSpeedPerSecondPerToken, // scaled in 1e18
          rewardTokenPrice: rewardTokenPrices[j],
          formattedAPR: apr, // scaled in 1e18
          flywheel: address(flywheel),
          rewardToken: rewardTokens[j]
        });
      }

      infoList[i] = MarketRewardsInfo({ market: market, rewardsInfo: rewardsInfo, underlyingPrice: price });
    }

    return infoList;
  }

  function scaleIndexDiff(uint256 indexDiff, uint256 decimals) internal view returns (uint256) {
    return decimals <= 18 ? uint256(indexDiff) * (10**(18 - decimals)) : uint256(indexDiff) / (10**(decimals - 18));
  }

  function getRewardSpeedPerSecondPerToken(MidasFlywheelCore flywheel, CErc20Token market, uint256 decimals)
    internal
    returns (uint256 rewardSpeedPerSecondPerToken)
  {
    (uint224 indexBefore, uint32 lastUpdatedTimestampBefore) = flywheel.strategyState(market);
    flywheel.accrue(market, address(0));
    (uint224 indexAfter, uint32 lastUpdatedTimestampAfter) = flywheel.strategyState(market);
    if (lastUpdatedTimestampAfter > lastUpdatedTimestampBefore) {
      rewardSpeedPerSecondPerToken =
        scaleIndexDiff((indexAfter - indexBefore), decimals) /
        (lastUpdatedTimestampAfter - lastUpdatedTimestampBefore);
    }
  }

  function getApr(
    uint256 rewardSpeedPerSecondPerToken,
    uint256 rewardTokenPrice,
    uint256 underlyingPrice,
    uint256 exchangeRate
  ) internal view returns (uint256) {
    if (rewardSpeedPerSecondPerToken == 0) return 0;
    uint256 nativeSpeedPerSecondPerCToken = rewardSpeedPerSecondPerToken * rewardTokenPrice; // scaled to 1e36
    uint256 nativeSpeedPerYearPerCToken = nativeSpeedPerSecondPerCToken * 365.25 days; // scaled to 1e36
    uint256 assetSpeedPerYearPerCToken = nativeSpeedPerYearPerCToken / underlyingPrice; // scaled to 1e18
    uint256 assetSpeedPerYearPerCTokenScaled = assetSpeedPerYearPerCToken * 1e18; // scaled to 1e36
    uint256 apr = assetSpeedPerYearPerCTokenScaled / exchangeRate; // scaled to 1e18
    return apr;
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
