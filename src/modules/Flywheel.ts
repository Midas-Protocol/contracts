import { BigNumber, Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat";
import FlywheelCoreArtifact from "../../artifacts/contracts/flywheel/FlywheelCore.sol/FlywheelCore.json";
import FuseFlywheelLensRouterArtifact from "../../artifacts/contracts/flywheel/fuse-compatibility/FuseFlywheelLensRouter.sol/FuseFlywheelLensRouter.json";
import FlywheelDynamicRewardsArtifact from "../../artifacts/contracts/flywheel/rewards/FlywheelDynamicRewards.sol/FlywheelDynamicRewards.json";
import FlywheelStaticRewardsArtifact from "../../artifacts/contracts/flywheel/rewards/FlywheelStaticRewards.sol/FlywheelStaticRewards.json";
import IFlywheelRewardsArtifact from "../../artifacts/contracts/flywheel/interfaces/IFlywheelRewards.sol/IFlywheelRewards.json";
import {
  FlywheelCore,
  FlywheelCore__factory,
  FlywheelStaticRewards,
  FlywheelStaticRewards__factory,
} from "../../typechain";
import { Comptroller } from "../../typechain/Comptroller";
import { FuseBaseConstructor } from "../Fuse/types";

export function withFlywheel<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class Flywheel extends Base {
    constructor(...args) {
      super(...args);
      this.artifacts.FlywheelCore = FlywheelCoreArtifact;
      this.artifacts.FlywheelDynamicRewardsArtifact = FlywheelDynamicRewardsArtifact;
      this.artifacts.FlywheelStaticRewards = FlywheelStaticRewardsArtifact;
      // TODO add ass Chain Deployment!
      this.artifacts.FuseFlywheelLensRouter = FuseFlywheelLensRouterArtifact;
      this.artifacts.IFlywheelRewards = IFlywheelRewardsArtifact;
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
        this.artifacts.FlywheelCore.abi,
        this.artifacts.FlywheelCore.bytecode,
        this.provider.getSigner()
      ) as FlywheelCore__factory;
      return (await flywheelCoreFactory.deploy(
        rewardTokenAddress,
        options.rewardsAddress || ethers.constants.AddressZero,
        options.boosterAddress || ethers.constants.AddressZero,
        options.ownerAddress || options.from,
        options.authorityAddress || ethers.constants.AddressZero
      )) as FlywheelCore;
    }

    async deployFlywheelStaticRewards(
      rewardTokenAddress: string,
      options: {
        from: string;
        flywheelCoreAddress?: string;
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
        options.flywheelCoreAddress || ethers.constants.AddressZero,
        options.ownerAddress || options.from,
        options.authorityAddress || ethers.constants.AddressZero
      )) as FlywheelStaticRewards;
    }

    setStaticRewardInfo(
      staticRewardsAddress: string,
      rewardTokenAddress: string,
      rewardInfo: FlywheelStaticRewards.RewardsInfoStruct,
      options: { from: string }
    ) {
      const flywheelCoreInstance = this.#getStaticRewardsInstance(staticRewardsAddress, options);
      return flywheelCoreInstance.functions.setRewardsInfo(rewardTokenAddress, rewardInfo);
    }

    addMarketForRewardsToFlywheelCore(flywheelCoreAddress: string, marketAddress: string, options: { from: string }) {
      const flywheelCoreInstance = this.#getFlywheelCoreInstance(flywheelCoreAddress, options);
      return flywheelCoreInstance.functions.addMarketForRewards(marketAddress);
    }

    addFlywheelCoreToPool(flywheelCoreAddress: string, poolAddress: string, options: { from: string }) {
      const comptrollerInstance = new Contract(
        poolAddress,
        this.artifacts.Comptroller.abi,
        this.provider.getSigner(options.from)
      ) as Comptroller;
      return comptrollerInstance.functions._addRewardsDistributor(flywheelCoreAddress);
    }

    #getStaticRewardsInstance(flywheelCoreAddress: string, options: { from: string }) {
      return new Contract(
        flywheelCoreAddress,
        this.artifacts.FlywheelStaticRewards.abi,
        this.provider.getSigner(options.from)
      ) as FlywheelStaticRewards;
    }

    #getFlywheelCoreInstance(flywheelCoreAddress: string, options: { from: string }) {
      return new Contract(
        flywheelCoreAddress,
        this.artifacts.FlywheelCore.abi,
        this.provider.getSigner(options.from)
      ) as FlywheelCore;
    }
  };
}
