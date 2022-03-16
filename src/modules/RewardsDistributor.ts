import { BigNumber, BigNumberish, Contract, ContractFactory } from "ethers";
import { Comptroller } from "../../typechain/Comptroller";
import { ERC20 } from "../../typechain/ERC20";
import { RewardsDistributorDelegate } from "../../typechain/RewardsDistributorDelegate";
import { FuseBaseConstructor } from "../Fuse/types";

interface Reward {
  distributor: string;
  rewardToken: string;
  speed: BigNumber;
}
interface MarketReward {
  cToken: string;
  supplyRewards: Reward[];
  borrowRewards: Reward[];
}

export function withRewardsDistributor<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class RewardsDistributor extends Base {
    #getRewardsDistributor(rewardsDistributorAddress: string, options: { from: string }) {
      return new Contract(
        rewardsDistributorAddress,
        this.chainDeployment.RewardsDistributorDelegate.abi,
        this.provider.getSigner(options.from)
      ) as RewardsDistributorDelegate;
    }

    async deployRewardsDistributor(rewardTokenAddress: string, options: { from: string }) {
      const rewardDistributorFactory = new ContractFactory(
        this.artifacts.RewardsDistributorDelegator.abi,
        this.artifacts.RewardsDistributorDelegator.bytecode,
        this.provider.getSigner()
      );
      return (await rewardDistributorFactory.deploy(
        options.from,
        rewardTokenAddress,
        this.chainDeployment.RewardsDistributorDelegate.address
      )) as RewardsDistributorDelegate;
    }

    addRewardsDistributorToPool(rewardsDistributorAddress: string, poolAddress: string, options: { from: string }) {
      const comptrollerInstance = new Contract(
        poolAddress,
        this.artifacts.Comptroller.abi,
        this.provider.getSigner(options.from)
      ) as Comptroller;
      return comptrollerInstance.functions._addRewardsDistributor(rewardsDistributorAddress);
    }

    claimRewardsDistributorRewards(
      rewardsDistributorAddress: string,
      cTokenAddress: string,
      amount: BigNumberish,
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(rewardsDistributorAddress, options);
      throw new Error("Not implemented");
    }

    async fundRewardsDistributor(rewardsDistributorAddress: string, amount: BigNumberish, options: { from: string }) {
      const rewardDistributorInstance = this.#getRewardsDistributor(rewardsDistributorAddress, options);

      const rewardTokenAddress = await rewardDistributorInstance.rewardToken();

      const tokenInstance = new Contract(
        rewardTokenAddress,
        this.artifacts.ERC20.abi,
        this.provider.getSigner(options.from)
      ) as ERC20;

      return tokenInstance.functions.transfer(rewardsDistributorAddress, amount);
    }

    getRewardsDistributorSupplySpeed(
      rewardsDistributorAddress: string,
      cTokenAddress: string,
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(rewardsDistributorAddress, options);
      return rewardDistributorInstance.compSupplySpeeds(cTokenAddress);
    }

    getRewardsDistributorBorrowSpeed(
      rewardsDistributorAddress: string,
      cTokenAddress: string,
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(rewardsDistributorAddress, options);
      return rewardDistributorInstance.compSupplySpeeds(cTokenAddress);
    }

    updateRewardsDistributorSupplySpeed(
      rewardsDistributorAddress: string,
      cTokenAddress: string,
      amount: BigNumberish,
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(rewardsDistributorAddress, options);

      return rewardDistributorInstance._setCompSupplySpeed(cTokenAddress, amount);
    }

    updateRewardsDistributorBorrowSpeed(
      rewardsDistributorAddress: string,
      cTokenAddress: string,
      amount: BigNumberish,
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(rewardsDistributorAddress, options);

      return rewardDistributorInstance._setCompBorrowSpeed(cTokenAddress, amount);
    }

    updateRewardsDistributorSpeeds(
      rewardsDistributorAddress: string,
      cTokenAddress: string[],
      amountSuppliers: BigNumberish[],
      amountBorrowers: BigNumberish[],
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(rewardsDistributorAddress, options);

      return rewardDistributorInstance._setCompSpeeds(cTokenAddress, amountSuppliers, amountBorrowers);
    }

    async getRewardsDistributorAccruedAmount(
      rewardsDistributorAddress: string,
      account: string,
      options: { from: string; blockNumber?: number }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(rewardsDistributorAddress, options);
      let claimableRewards = await rewardDistributorInstance.compAccrued(account);
      const lastUpdated = await rewardDistributorInstance.lastContributorBlock(account);
      if (options.blockNumber && options.blockNumber > lastUpdated.toNumber()) {
        const diff = options.blockNumber - lastUpdated.toNumber();
        console.log({ diff });
        const rewardsPerBlock = await rewardDistributorInstance.compContributorSpeeds(account);
        console.log({ rewardsPerBlock });
        claimableRewards = claimableRewards.add(rewardsPerBlock.mul(diff));
      }
      console.log({ claimableRewards });
      return claimableRewards;
    }

    #createMarketRewards(
      allMarkets: string[],
      distributors: string[],
      rewardTokens: string[],
      supplySpeeds: BigNumber[][],
      borrowSpeeds: BigNumber[][]
    ): MarketReward[] {
      const marketRewards: MarketReward[] = allMarkets.map((market, marketIndex) => ({
        cToken: market,
        supplyRewards: supplySpeeds[marketIndex]
          .filter((speed) => speed.gt(0))
          .map((speed, speedIndex) => ({
            distributor: distributors[speedIndex],
            rewardToken: rewardTokens[speedIndex],
            speed,
          })),
        borrowRewards: borrowSpeeds[marketIndex]
          .filter((speed) => speed.gt(0))
          .map((speed, speedIndex) => ({
            distributor: distributors[speedIndex],
            rewardToken: rewardTokens[speedIndex],
            speed,
          })),
      }));

      return marketRewards;
    }

    async getMarketRewardsByPool(pool: string, options: { from: string }): Promise<MarketReward[]> {
      const rewardSpeedsByPoolResponse = await this.contracts.FusePoolLensSecondary.callStatic.getRewardSpeedsByPool(
        pool,
        options
      );
      return this.#createMarketRewards(...rewardSpeedsByPoolResponse);
    }

    async getMarketRewardsByPools(
      pools: string[],
      options: { from: string }
    ): Promise<
      {
        pool: string;
        marketRewards: MarketReward[];
      }[]
    > {
      const [allMarkets, distributors, rewardTokens, supplySpeeds, borrowSpeeds] =
        await this.contracts.FusePoolLensSecondary.callStatic.getRewardSpeedsByPools(pools, options);
      const poolsWithMarketRewards = pools.map((pool, index) => ({
        pool,
        marketRewards: this.#createMarketRewards(
          allMarkets[index],
          distributors[index],
          rewardTokens[index],
          supplySpeeds[index],
          borrowSpeeds[index]
        ),
      }));

      return poolsWithMarketRewards;
    }
  };
}
