import { BigNumber, BigNumberish, Contract, ContractFactory } from "ethers";
import { Comptroller } from "../../typechain/Comptroller";
import { ERC20 } from "../../typechain/ERC20";
import { RewardsDistributorDelegate } from "../../typechain/RewardsDistributorDelegate";
import { FuseBaseConstructor } from "../Fuse/types";
import FlyWheelCoreArtifact from "../../artifacts/contracts/flywheel/FlyWheelCore.sol/FlyWheelCore.json";
import { FlywheelCore, FlywheelCore__factory } from "../../typechain";
import { ethers } from "hardhat";

export function withFlywheel<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class Flywheel extends Base {
    constructor(...args) {
      super(...args);
      this.artifacts.FlyWheelCore = FlyWheelCoreArtifact;
    }

    async deployFlywheel(
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
        this.artifacts.FlyWheelCore.abi,
        this.artifacts.FlyWheelCore.bytecode,
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
  };
}
