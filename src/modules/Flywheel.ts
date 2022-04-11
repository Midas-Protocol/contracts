import { info } from "console";
import { BigNumber, constants, Contract, ContractFactory } from "ethers";
import { FlywheelStaticRewards__factory } from "../../typechain/factories/FlywheelStaticRewards__factory";
import { FuseFlywheelCore__factory } from "../../typechain/factories/FuseFlywheelCore__factory";
import { FlywheelStaticRewards } from "../../typechain/FlywheelStaticRewards";
import { FuseFlywheelCore } from "../../typechain/FuseFlywheelCore";
import { FuseFlywheelLensRouter } from "../../typechain/FuseFlywheelLensRouter.sol";
import { FuseBaseConstructor } from "../Fuse/types";

export interface FlywheelClaimableRewards {
  flywheel: string;
  rewardToken: string;
  rewards: Array<{
    market: string;
    amount: BigNumber;
  }>;
}

export type FlywheelMarketRewardsInfo = {
  underlyingPrice: BigNumber;
  market: string;
  rewardsInfo: {
    rewardToken: string;
    flywheel: string;
    rewardSpeedPerSecondPerToken: BigNumber;
    rewardTokenPrice: BigNumber;
    formattedAPR: BigNumber;
  }[];
  rewardTokens: string[];
};

export function withFlywheel<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class Flywheel extends Base {
    async deployFlywheelCore(
      rewardTokenAddress: string,
      options: {
        from: string;
        rewardsAddress?: string;
        boosterAddress?: string;
        ownerAddress?: string;
        authorityAddress?: string;
      }
    ) {
      const flywheelCoreFactory = new ContractFactory(
        this.artifacts.FuseFlywheelCore.abi,
        this.artifacts.FuseFlywheelCore.bytecode,
        this.provider.getSigner()
      ) as FuseFlywheelCore__factory;
      return (await flywheelCoreFactory.deploy(
        rewardTokenAddress,
        options.rewardsAddress || constants.AddressZero,
        options.boosterAddress || constants.AddressZero,
        options.ownerAddress || options.from,
        options.authorityAddress || constants.AddressZero
      )) as FuseFlywheelCore;
    }

    async deployFlywheelStaticRewards(
      rewardTokenAddress: string,
      flywheelCoreAddress: string,
      options: {
        from: string;
        ownerAddress?: string;
        authorityAddress?: string;
      }
    ) {
      const fwStaticRewardsFactory = new ContractFactory(
        this.artifacts.FlywheelStaticRewards.abi,
        this.artifacts.FlywheelStaticRewards.bytecode,
        this.provider.getSigner()
      ) as FlywheelStaticRewards__factory;

      return (await fwStaticRewardsFactory.deploy(
        flywheelCoreAddress,
        options.ownerAddress || options.from,
        options.authorityAddress || constants.AddressZero
      )) as FlywheelStaticRewards;
    }

    setStaticRewardInfo(
      staticRewardsAddress: string,
      marketAddress: string,
      rewardInfo: FlywheelStaticRewards.RewardsInfoStruct,
      options: { from: string }
    ) {
      const staticRewardsInstance = this.getStaticRewardsInstance(staticRewardsAddress, options);
      return staticRewardsInstance.functions.setRewardsInfo(marketAddress, rewardInfo);
    }

    setFlywheelRewards(flywheelAddress: string, rewardsAddress: string, options: { from: string }) {
      const flywheelCoreInstance = this.getFlywheelCoreInstance(flywheelAddress, options);
      return flywheelCoreInstance.functions.setFlywheelRewards(rewardsAddress);
    }

    addMarketForRewardsToFlywheelCore(flywheelCoreAddress: string, marketAddress: string, options: { from: string }) {
      return this.addStrategyForRewardsToFlywheelCore(flywheelCoreAddress, marketAddress, options);
    }

    addStrategyForRewardsToFlywheelCore(flywheelCoreAddress: string, marketAddress: string, options: { from: string }) {
      const flywheelCoreInstance = this.getFlywheelCoreInstance(flywheelCoreAddress, options);
      return flywheelCoreInstance.functions.addStrategyForRewards(marketAddress, options);
    }

    addFlywheelCoreToComptroller(flywheelCoreAddress: string, comptrollerAddress: string, options: { from: string }) {
      const comptrollerInstance = this.getComptrollerInstance(comptrollerAddress, options);
      return comptrollerInstance.functions._addRewardsDistributor(flywheelCoreAddress, options);
    }

    async accrueFlywheel(
      flywheelAddress: string,
      accountAddress: string,
      marketAddress: string,
      options: { from: string }
    ) {
      const flywheelCoreInstance = this.getFlywheelCoreInstance(flywheelAddress, options);
      return flywheelCoreInstance.functions["accrue(address,address)"](marketAddress, accountAddress, options);
    }

    async getFlywheelClaimableRewardsForPool(poolAddress: string, account: string, options: { from: string }) {
      const pool = await this.getComptrollerInstance(poolAddress, options);
      const marketsOfPool = await pool.getAllMarkets();

      const rewardDistributorsOfPool = await pool.getRewardsDistributors();
      const flywheels = rewardDistributorsOfPool.map((address) => this.getFlywheelCoreInstance(address, options));
      const flywheelWithRewards: FlywheelClaimableRewards[] = [];
      for (const flywheel of flywheels) {
        const rewards: FlywheelClaimableRewards["rewards"] = [];
        for (const market of marketsOfPool) {
          const rewardOfMarket = await flywheel.callStatic["accrue(address,address)"](market, account);
          if (rewardOfMarket.gt(0)) {
            rewards.push({
              market,
              amount: rewardOfMarket,
            });
          }
        }
        if (rewards.length > 0) {
          flywheelWithRewards.push({
            flywheel: flywheel.address,
            rewardToken: await flywheel.rewardToken(),
            rewards,
          });
        }
      }
      return flywheelWithRewards;
    }

    async getFlywheelClaimableRewards(account: string, options: { from: string }) {
      const [comptrollerIndexes, comptrollers, flywheels] =
        await this.contracts.FusePoolLensSecondary.callStatic.getRewardsDistributorsBySupplier(account, options);

      return (
        await Promise.all(comptrollers.map((comp) => this.getFlywheelClaimableRewardsForPool(comp, account, options)))
      )
        .reduce((acc, curr) => [...acc, ...curr], []) // Flatten Array
        .filter((value, index, self) => self.indexOf(value) === index); // Unique Array;
    }

    async getFlywheelMarketRewardsByPool(
      pool: string,
      options: { from: string }
    ): Promise<FlywheelMarketRewardsInfo[]> {
      const marketRewards = await (
        this.contracts.FuseFlywheelLensRouter as FuseFlywheelLensRouter
      ).callStatic.getMarketRewardsInfo(pool, options);

      console.log({ rawMarketRewards: marketRewards });

      const adaptedMarketRewards = marketRewards.map((marketReward) => ({
        underlyingPrice: marketReward.underlyingPrice,
        market: marketReward.market,
        rewardsInfo: marketReward.rewardsInfo
          .filter((info) => info.rewardSpeedPerSecondPerToken.gt(0))
          .map((info) => ({
            rewardToken: info.rewardToken,
            flywheel: info.flywheel,
            rewardSpeedPerSecondPerToken: info.rewardSpeedPerSecondPerToken,
            rewardTokenPrice: info.rewardTokenPrice,
            formattedAPR: info.formattedAPR,
          })),
        rewardTokens: marketReward.rewardsInfo
          .filter((info) => info.rewardSpeedPerSecondPerToken.gt(0))
          .map((info) => info.rewardToken),
      }));
      return adaptedMarketRewards;
    }

    async getFlywheelMarketRewardsByPools(pools: string[], options: { from: string }) {
      return Promise.all(pools.map((pool) => this.getFlywheelMarketRewardsByPool(pool, options)));
    }

    async getFlywheelRewardsInfos(flywheelAddress: string, options: { from: string }) {
      const flywheelCoreInstance = this.getFlywheelCoreInstance(flywheelAddress, options);
      const [fwStaticAddress, enabledMarkets] = await Promise.all([
        flywheelCoreInstance.callStatic.flywheelRewards(options),
        flywheelCoreInstance.callStatic.getAllStrategies(options),
      ]);
      const fwStatic = this.getStaticRewardsInstance(fwStaticAddress, options);
      const rewardsInfos = {};
      await Promise.all(
        enabledMarkets.map(async (m) => {
          rewardsInfos[m] = await fwStatic.callStatic.rewardsInfo(m);
        })
      );
      return rewardsInfos;
    }

    async getFlywheelRewardsInfoForMarket(flywheelAddress: string, marketAddress: string, options: { from: string }) {
      const fwCoreInstance = this.getFlywheelCoreInstance(flywheelAddress, options);
      const fwRewardsAddress = await fwCoreInstance.callStatic.flywheelRewards(options);
      const fwRewardsInstance = this.getStaticRewardsInstance(fwRewardsAddress, options);
      const [marketState, rewardsInfo] = await Promise.all([
        await fwCoreInstance.callStatic.marketState(marketAddress, options),
        fwRewardsInstance.callStatic.rewardsInfo(marketAddress, options),
      ]);
      return {
        enabled: marketState.lastUpdatedTimestamp > 0,
        ...rewardsInfo,
      };
    }

    async getFlywheelsByPool(poolAddress: string, options: { from: string }) {
      const comptrollerInstance = this.getComptrollerInstance(poolAddress, options);
      const allRewardDistributors = await comptrollerInstance.callStatic.getRewardsDistributors(options);
      const instances = allRewardDistributors.map((address) => {
        return new Contract(
          address,
          this.artifacts.FuseFlywheelCore.abi,
          this.provider.getSigner(options.from)
        ) as FuseFlywheelCore;
      });

      const filterList = await Promise.all(
        instances.map(async (instance) => {
          try {
            return await instance.callStatic.isFlywheel(options);
          } catch (error) {
            return false;
          }
        })
      );

      return instances.filter((_, index) => filterList[index]);
    }

    getStaticRewardsInstance(flywheelCoreAddress: string, options: { from: string }) {
      return new Contract(
        flywheelCoreAddress,
        this.artifacts.FlywheelStaticRewards.abi,
        this.provider.getSigner(options.from)
      ) as FlywheelStaticRewards;
    }

    getFlywheelCoreInstance(flywheelCoreAddress: string, options: { from: string }) {
      return new Contract(
        flywheelCoreAddress,
        this.artifacts.FuseFlywheelCore.abi,
        this.provider.getSigner(options.from)
      ) as FuseFlywheelCore;
    }
  };
}
