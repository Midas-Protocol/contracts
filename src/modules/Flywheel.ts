import { BigNumber, constants, Contract, ContractFactory } from "ethers";
import FlywheelCoreArtifact from "../../artifacts/contracts/flywheel/FlywheelCore.sol/FlywheelCore.json";
import FuseFlywheelCoreArtifact from "../../artifacts/contracts/flywheel/fuse-compatibility/FuseFlywheelCore.sol/FuseFlywheelCore.json";
import FlywheelDynamicRewardsArtifact from "../../artifacts/contracts/flywheel/rewards/FlywheelDynamicRewards.sol/FlywheelDynamicRewards.json";
import FlywheelStaticRewardsArtifact from "../../artifacts/contracts/flywheel/rewards/FlywheelStaticRewards.sol/FlywheelStaticRewards.json";
import { FuseFlywheelCore__factory } from "../../typechain";
import { FlywheelStaticRewards__factory } from "../../typechain/factories/FlywheelStaticRewards__factory";
import { FlywheelCore } from "../../typechain/FlywheelCore";
import { FlywheelStaticRewards } from "../../typechain/FlywheelStaticRewards";
import { FuseFlywheelCore } from "../../typechain/FuseFlywheelCore";
import { FuseBaseConstructor } from "../Fuse/types";

export interface FlywheelReward {
  distributor: string;
  rewardToken: string;
  rewardsPerSecond: BigNumber;
  rewardsEndTimestamp: number;
}
export interface FlywheelMarketReward {
  cToken: string;
  supplyRewards: FlywheelReward[];
  borrowRewards: FlywheelReward[];
}

export function withFlywheel<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class Flywheel extends Base {
    constructor(...args) {
      super(...args);
      this.artifacts.FlywheelCore = FlywheelCoreArtifact;
      this.artifacts.FuseFlywheelCore = FuseFlywheelCoreArtifact;
      this.artifacts.FlywheelDynamicRewardsArtifact = FlywheelDynamicRewardsArtifact;
      this.artifacts.FlywheelStaticRewards = FlywheelStaticRewardsArtifact;
    }

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
      const flywheelCoreInstance = this.getFlywheelCoreInstance(flywheelCoreAddress, options);
      return flywheelCoreInstance.functions.addMarketForRewards(marketAddress, options);
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

    async getFlywheelClaimableRewards(account: string, options: { from: string }) {
      const [comptrollerIndexes, comptrollers, flywheels] =
        await this.contracts.FusePoolLensSecondary.callStatic.getRewardsDistributorsBySupplier(account, options);
      console.dir({ comptrollerIndexes, comptrollers, flywheels }, { depth: null });
      const uniqueFlywheels = flywheels
        .reduce((acc, curr) => [...acc, ...curr], []) // Flatten Array
        .filter((value, index, self) => self.indexOf(value) === index); // Unique Array

      console.dir({ uniqueFlywheels }, { depth: null });

      const allMarkets1 = comptrollers.map((compAddress) => this.getComptrollerInstance(compAddress, options));
      // .map((comptroller) => comptroller.get);

      const compWithWheelsAndMarkets = await Promise.all(
        comptrollers
          .map((compAddress) => this.getComptrollerInstance(compAddress, options))
          .map(async (comptroller, index) => {
            return {
              comptroller: comptroller.address,
              flywheels: flywheels[index],
              markets: await comptroller.callStatic.getAllMarkets(),
            };
          })
      );
      console.dir({ compWithWheelsAndMarkets }, { depth: null });

      const rewardTokens1 = await Promise.all(
        uniqueFlywheels
          .map((fwAddress) => this.getFlywheelCoreInstance(fwAddress, options))
          .map((fwCore) => fwCore.functions.rewardToken())
      );
      const fwRewards = await Promise.all(
        uniqueFlywheels
          .map((fwAddress) => this.getFlywheelCoreInstance(fwAddress, options))
          .map((fwCore) => fwCore.functions.flywheelRewards())
      );
      console.log({ fwRewards, rewardTokens1 });

      const [allMarkets, distributors, rewardTokens, supplySpeeds, borrowSpeeds] =
        await this.contracts.FusePoolLensSecondary.callStatic.getRewardSpeedsByPools(comptrollers, options);
      console.dir({ allMarkets, distributors, rewardTokens, supplySpeeds, borrowSpeeds }, { depth: null });
      return {};

      // {
      //   distributor: string;
      //   rewardToken: string;
      //   amount: BigNumber;
      // }
      // return this.contracts.FuseFlywheelLensRouter.callStatic.getUnclaimedRewardsByMarkets(
      //   account,
      //   [marketAddress],
      //   [flywheel],
      //   [true],
      //   [false],
      //   options
      // );

      // const [rewardTokens, compUnclaimedTotal, allMarkets, rewardsUnaccrued, distributorFunds] =
      //   await this.contracts.FusePoolLensSecondary.callStatic.getUnclaimedRewardsByDistributors(
      //     account,
      //     uniqueRewardsDistributors,
      //     options
      //   );

      // const claimableRewards: ClaimableReward[] = uniqueRewardsDistributors
      //   .filter((_, index) => compUnclaimedTotal[index].gt(0)) // Filter out Distributors without Rewards
      //   .map((distributor, index) => ({
      //     distributor,
      //     rewardToken: rewardTokens[index],
      //     amount: compUnclaimedTotal[index],
      //   }));
      // return claimableRewards;
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
        this.artifacts.FlywheelCore.abi,
        this.provider.getSigner(options.from)
      ) as FlywheelCore;
    }

    async #createMarketRewards(pool: string, options: { from: string }): Promise<FlywheelMarketReward[]> {
      const comptroller = await this.getComptrollerInstance(pool, options);
      const allMarketsOfPool = await comptroller.getAllMarkets();
      const allFlywheelsOfPool = (await comptroller.getRewardsDistributors()).map((fw) =>
        this.getFlywheelCoreInstance(fw, options)
      );

      const marketRewards: FlywheelMarketReward[] = [];
      for (const market of allMarketsOfPool) {
        const supplyRewards = [];
        for (const flywheel of allFlywheelsOfPool) {
          const rewards = this.getStaticRewardsInstance(await flywheel.flywheelRewards(), options);
          const rewardsInfoForMarket = await rewards.rewardsInfo(market);
          if (rewardsInfoForMarket.rewardsPerSecond.gt(0)) {
            const rewardToken = await rewards.rewardToken();
            supplyRewards.push({
              distributor: flywheel.address,
              rewardToken,
              rewardsPerSecond: rewardsInfoForMarket.rewardsPerSecond,
              rewardsEndTimestamp: rewardsInfoForMarket.rewardsEndTimestamp,
            });
          }
        }
        if (supplyRewards.length > 0) {
          marketRewards.push({
            cToken: market,
            supplyRewards,
            borrowRewards: [],
          });
        }
      }
      return marketRewards;
    }
  };
}
