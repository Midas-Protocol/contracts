import { BigNumberish, Contract, ContractFactory } from "ethers";
import { Comptroller, ERC20, RewardsDistributorDelegate } from "../../typechain";
import { FuseBaseConstructor } from "../Fuse/types";

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
  };
}
