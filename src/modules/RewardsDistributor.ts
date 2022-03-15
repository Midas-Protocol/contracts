import { BigNumberish, Contract, ContractFactory } from "ethers";
import { ERC20, RewardsDistributorDelegate } from "../../typechain";
import { FuseBaseConstructor } from "../Fuse/types";

export function withRewardsDistributor<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class RewardsDistributor extends Base {
    #getRewardsDistributor(distributorAddress: string, options: { from: string }) {
      return new Contract(
        distributorAddress,
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

    addRewardsDistributor(comptrollerAddress: string, distributorAddress: string, options: { from: string }) {
      const comptrollerInstance = new Contract(
        comptrollerAddress,
        this.artifacts.Comptroller.abi,
        this.provider.getSigner(options.from)
      );
      return comptrollerInstance.functions._addRewardsDistributor(distributorAddress);
    }

    claimRewards(distributorAddress: string, cTokenAddress: string, amount: BigNumberish, options: { from: string }) {
      const rewardDistributorInstance = this.#getRewardsDistributor(distributorAddress, options);
      throw new Error("Not implemented");
    }

    async fundRewardsDistributor(distributorAddress: string, amount: BigNumberish, options: { from: string }) {
      const rewardDistributorInstance = this.#getRewardsDistributor(distributorAddress, options);

      const rewardTokenAddress = await rewardDistributorInstance.rewardToken();

      const tokenInstance = new Contract(
        rewardTokenAddress,
        this.artifacts.ERC20.abi,
        this.provider.getSigner(options.from)
      ) as ERC20;

      return tokenInstance.functions.transfer(distributorAddress, amount);
    }

    updateDistributionSpeedSuppliers(
      distributorAddress: string,
      cTokenAddress: string,
      amount: BigNumberish,
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(distributorAddress, options);

      return rewardDistributorInstance._setCompSupplySpeed(cTokenAddress, amount);
    }

    updateDistributionSpeedBorrowers(
      distributorAddress: string,
      cTokenAddress: string,
      amount: BigNumberish,
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(distributorAddress, options);

      return rewardDistributorInstance._setCompBorrowSpeed(cTokenAddress, amount);
    }

    updateDistributionSpeed(
      distributorAddress: string,
      cTokenAddress: string[],
      amountSuppliers: BigNumberish[],
      amountBorrowers: BigNumberish[],
      options: { from: string }
    ) {
      const rewardDistributorInstance = this.#getRewardsDistributor(distributorAddress, options);

      return rewardDistributorInstance._setCompSpeeds(cTokenAddress, amountSuppliers, amountBorrowers);
    }
  };
}
