// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { MidasFlywheelCore } from "./MidasFlywheelCore.sol";
import { IComptroller } from "../../../compound/ComptrollerInterface.sol";
import { ICErc20 } from "../../../compound/CTokenInterfaces.sol";
import { BasePriceOracle } from "../../../oracles/BasePriceOracle.sol";
import { FusePoolDirectory } from "../../../FusePoolDirectory.sol";

interface IPriceOracle {
  function getUnderlyingPrice(ERC20 cToken) external view returns (uint256);

  function price(address underlying) external view returns (uint256);
}

contract MidasFlywheelLensRouter {
  FusePoolDirectory public fpd;

  constructor(FusePoolDirectory _fpd) {
    fpd = _fpd;
  }

  struct MarketRewardsInfo {
    /// @dev comptroller oracle price of market underlying
    uint256 underlyingPrice;
    ICErc20 market;
    RewardsInfo[] rewardsInfo;
  }

  struct RewardsInfo {
    /// @dev rewards in `rewardToken` paid per underlying staked token in `market` per second
    uint256 rewardSpeedPerSecondPerToken;
    /// @dev comptroller oracle price of reward token
    uint256 rewardTokenPrice;
    /// @dev APR scaled by 1e18. Calculated as rewardSpeedPerSecondPerToken * rewardTokenPrice * 365.25 days / underlyingPrice * 1e18 / market.exchangeRate
    uint256 formattedAPR;
    address flywheel;
    address rewardToken;
  }

  function getPoolMarketRewardsInfo(IComptroller comptroller) external returns (MarketRewardsInfo[] memory) {
    ICErc20[] memory markets = comptroller.getAllMarkets();
    return _getMarketRewardsInfo(markets, comptroller);
  }

  function getMarketRewardsInfo(ICErc20[] memory markets) external returns (MarketRewardsInfo[] memory) {
    IComptroller pool;
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 asMarket = ICErc20(address(markets[i]));
      if (address(pool) == address(0)) pool = asMarket.comptroller();
      else require(asMarket.comptroller() == pool);
    }
    return _getMarketRewardsInfo(markets, pool);
  }

  function _getMarketRewardsInfo(ICErc20[] memory markets, IComptroller comptroller)
    internal
    returns (MarketRewardsInfo[] memory)
  {
    if (address(comptroller) == address(0) || markets.length == 0) return new MarketRewardsInfo[](0);

    address[] memory flywheels = comptroller.getAccruingFlywheels();
    address[] memory rewardTokens = new address[](flywheels.length);
    uint256[] memory rewardTokenPrices = new uint256[](flywheels.length);
    uint256[] memory rewardTokenDecimals = new uint256[](flywheels.length);
    BasePriceOracle oracle = comptroller.oracle();

    MarketRewardsInfo[] memory infoList = new MarketRewardsInfo[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      RewardsInfo[] memory rewardsInfo = new RewardsInfo[](flywheels.length);

      ICErc20 market = ICErc20(address(markets[i]));
      uint256 price = oracle.price(market.underlying()); // scaled to 1e18

      if (i == 0) {
        for (uint256 j = 0; j < flywheels.length; j++) {
          ERC20 rewardToken = MidasFlywheelCore(flywheels[j]).rewardToken();
          rewardTokens[j] = address(rewardToken);
          rewardTokenPrices[j] = oracle.price(address(rewardToken)); // scaled to 1e18
          rewardTokenDecimals[j] = uint256(rewardToken.decimals());
        }
      }

      for (uint256 j = 0; j < flywheels.length; j++) {
        MidasFlywheelCore flywheel = MidasFlywheelCore(flywheels[j]);

        uint256 rewardSpeedPerSecondPerToken = getRewardSpeedPerSecondPerToken(
          flywheel,
          market,
          rewardTokenDecimals[j]
        );
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

  function scaleIndexDiff(uint256 indexDiff, uint256 decimals) internal pure returns (uint256) {
    return decimals <= 18 ? uint256(indexDiff) * (10**(18 - decimals)) : uint256(indexDiff) / (10**(decimals - 18));
  }

  function getRewardSpeedPerSecondPerToken(
    MidasFlywheelCore flywheel,
    ICErc20 market,
    uint256 decimals
  ) internal returns (uint256 rewardSpeedPerSecondPerToken) {
    ERC20 strategy = ERC20(address(market));
    (uint224 indexBefore, uint32 lastUpdatedTimestampBefore) = flywheel.strategyState(strategy);
    flywheel.accrue(strategy, address(0));
    (uint224 indexAfter, uint32 lastUpdatedTimestampAfter) = flywheel.strategyState(strategy);
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
  ) internal pure returns (uint256) {
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
  )
    external
    returns (
      MidasFlywheelCore[] memory,
      address[] memory rewardTokens,
      uint256[] memory rewards
    )
  {
    uint256 size = flywheels.length;
    rewards = new uint256[](size);
    rewardTokens = new address[](size);

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
      rewardTokens[i] = address(flywheels[i].rewardToken());
    }

    return (flywheels, rewardTokens, rewards);
  }

  function getUnclaimedRewardsForPool(address user, IComptroller comptroller)
    public
    returns (
      MidasFlywheelCore[] memory,
      address[] memory,
      uint256[] memory
    )
  {
    ICErc20[] memory cerc20s = comptroller.getAllMarkets();
    ERC20[] memory markets = new ERC20[](cerc20s.length);
    address[] memory flywheelAddresses = comptroller.getAccruingFlywheels();
    MidasFlywheelCore[] memory flywheels = new MidasFlywheelCore[](flywheelAddresses.length);
    address[] memory rewardTokens = new address[](flywheelAddresses.length);
    bool[] memory accrue = new bool[](flywheelAddresses.length);

    for (uint256 j = 0; j < flywheelAddresses.length; j++) {
      flywheels[j] = MidasFlywheelCore(flywheelAddresses[j]);
      rewardTokens[j] = address(flywheels[j].rewardToken());
      accrue[j] = true;
    }

    for (uint256 j = 0; j < cerc20s.length; j++) {
      markets[j] = ERC20(address(cerc20s[j]));
    }

    return getUnclaimedRewardsByMarkets(user, markets, flywheels, accrue);
  }

  function getUnclaimedRewardsByMarkets(
    address user,
    ERC20[] memory markets,
    MidasFlywheelCore[] memory flywheels,
    bool[] memory accrue
  )
    public
    returns (
      MidasFlywheelCore[] memory,
      address[] memory rewardTokens,
      uint256[] memory rewards
    )
  {
    rewards = new uint256[](flywheels.length);
    rewardTokens = new address[](flywheels.length);

    for (uint256 i = 0; i < flywheels.length; i++) {
      for (uint256 j = 0; j < markets.length; j++) {
        ERC20 market = markets[j];

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
      rewardTokens[i] = address(flywheels[i].rewardToken());
    }

    return (flywheels, rewardTokens, rewards);
  }

  function getAllRewardTokens() public view returns (address[] memory rewardTokens) {
    (, FusePoolDirectory.FusePool[] memory pools) = fpd.getActivePools();

    uint256 rewardTokensCounter;
    for (uint256 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);
      address[] memory fws = pool.getRewardsDistributors();

      rewardTokensCounter += fws.length;
    }

    rewardTokens = new address[](rewardTokensCounter);
    for (uint256 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);
      address[] memory fws = pool.getRewardsDistributors();

      for (uint256 j = 0; j < fws.length; j++) {
        rewardTokens[--rewardTokensCounter] = address(MidasFlywheelCore(fws[j]).rewardToken());
      }
    }
  }
}
