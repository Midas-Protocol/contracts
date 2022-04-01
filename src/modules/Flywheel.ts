import { BigNumber, constants, Contract, ContractFactory } from "ethers";
import { FlywheelStaticRewards__factory } from "../../typechain/factories/FlywheelStaticRewards__factory";
import { FuseFlywheelCore__factory } from "../../typechain/factories/FuseFlywheelCore__factory";
import { FlywheelStaticRewards } from "../../typechain/FlywheelStaticRewards";
import { FuseFlywheelCore } from "../../typechain/FuseFlywheelCore";
import { FuseBaseConstructor } from "../Fuse/types";

export interface FlywheelClaimableRewards {
  flywheel: string;
  rewardToken: string;
  rewards: [
    {
      market: string;
      amount: BigNumber;
    }?
  ];
}
export interface FlywheelReward {
  distributor: string;
  rewardToken: string;
  rewardsPerSecond: BigNumber;
  rewardsEndTimestamp: number;
}
export interface FlywheelMarketReward {
  market: string;
  supplyRewards: FlywheelReward[];
  borrowRewards: FlywheelReward[];
}

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
        rewardTokenAddress,
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

    async getFlywheelMarketRewardsByPool(pool: string, options: { from: string }): Promise<FlywheelMarketReward[]> {
      return this.#createMarketRewards(pool, options);
    }

    async getFlywheelMarketRewardsByPools(
      pools: string[],
      options: { from: string }
    ): Promise<
      {
        pool: string;
        marketRewards: FlywheelMarketReward[];
      }[]
    > {
      return Promise.all(
        pools.map(async (pool) => ({
          pool,
          marketRewards: await this.#createMarketRewards(pool, options),
        }))
      );
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

    async #createMarketRewards(pool: string, options: { from: string }): Promise<FlywheelMarketReward[]> {
      const comptroller = await this.getComptrollerInstance(pool, options);
      const allMarketsOfPool = await comptroller.callStatic.getAllMarkets(options);
      const allFlywheelsOfPool = await this.getFlywheelsByPool(pool, options);

      const marketRewards: FlywheelMarketReward[] = [];
      for (const market of allMarketsOfPool) {
        const supplyRewards: FlywheelMarketReward["supplyRewards"] = [];
        for (const flywheel of allFlywheelsOfPool) {
          // Make sure Market is added to the flywheel
          const marketState = await flywheel.callStatic.marketState(market, options);
          if (marketState.lastUpdatedTimestamp > 0) {
            // Get Rewards and only add if greater than 0
            const rewards = this.getStaticRewardsInstance(await flywheel.callStatic.flywheelRewards(options), options);
            const rewardsInfoForMarket = await rewards.rewardsInfo(market, options);
            if (rewardsInfoForMarket.rewardsPerSecond.gt(0)) {
              const rewardToken = await rewards.rewardToken(options);
              supplyRewards.push({
                distributor: flywheel.address,
                rewardToken,
                rewardsPerSecond: rewardsInfoForMarket.rewardsPerSecond,
                rewardsEndTimestamp: rewardsInfoForMarket.rewardsEndTimestamp,
              });
            }
          }
        }
        if (supplyRewards.length > 0) {
          marketRewards.push({
            market,
            supplyRewards,
            borrowRewards: [],
          });
        }
      }
      return marketRewards;
    }
  };
}
