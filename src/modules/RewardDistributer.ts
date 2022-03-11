import { BigNumberish, Contract, ContractFactory } from "ethers";
import { FuseBaseConstructor } from "../Fuse/types";

export function withRewardDistributer<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class RewardDistributer extends Base {
    deployRewardsDistributor(rewardToken: string, options: { from: string }) {
      const rewardDistributorFactory = new ContractFactory(
        this.artifacts.RewardsDistributorDelegator.abi,
        this.artifacts.RewardsDistributorDelegator.bytecode,
        this.provider.getSigner()
      );
      return rewardDistributorFactory.deploy(
        options.from,
        rewardToken,
        this.chainDeployment.RewardsDistributorDelegate.address
      );
    }

    addRewardDistributer(comptrollerAddress: string, distributorAddress: string, options: { from: string }) {
      const comptrollerInstance = new Contract(
        comptrollerAddress,
        this.artifacts.Comptroller.abi,
        this.provider.getSigner(options.from)
      );
      return comptrollerInstance.functions._addRewardsDistributor(distributorAddress);
    }

    fundRewardDistributer(
      distributorAddress: string,
      tokenAddress: string,
      amount: BigNumberish,
      options: { from: any }
    ) {
      const tokenInstance = new Contract(tokenAddress, this.artifacts.ERC20.abi, this.provider.getSigner(options.from));
      return tokenInstance.functions.transfer(distributorAddress, amount);
    }

    updateDistributionSpeedSuppliers(
      distributorAddress: string,
      cTokenAddress: string,
      amount: BigNumberish,
      options: { from: any }
    ) {
      const rewardDistributerInstance = new Contract(
        distributorAddress,
        this.chainDeployment.RewardsDistributorDelegate.abi,
        this.provider.getSigner(options.from)
      );
      return rewardDistributerInstance._setCompSupplySpeed(cTokenAddress, amount);
    }

    updateDistributionSpeedBorrowers(
      distributorAddress: string,
      cTokenAddress: string,
      amount: BigNumberish,
      options: { from: any }
    ) {
      const rewardDistributerInstance = new Contract(
        distributorAddress,
        this.chainDeployment.RewardsDistributorDelegate.abi,
        this.provider.getSigner(options.from)
      );
      return rewardDistributerInstance._setCompBorrowSpeed(cTokenAddress, amount);
    }

    updateDistributionSpeed(
      distributorAddress: string,
      cTokenAddress: string,
      amountSuppliers: BigNumberish,
      amountBorrowers: BigNumberish,
      options: { from: any }
    ) {
      const rewardDistributerInstance = new Contract(
        distributorAddress,
        this.chainDeployment.RewardsDistributorDelegate.abi,
        this.provider.getSigner(options.from)
      );
      return rewardDistributerInstance._setCompSpeeds(cTokenAddress, amountSuppliers, amountBorrowers);
    }
  };
}
