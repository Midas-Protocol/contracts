import { BigNumber, BigNumberish, Contract } from "ethers";
import { Web3Provider } from "@ethersproject/providers";

import { InterestRateModel } from "../types";
import JumpRateModelArtifact from "../../../artifacts/contracts/compound/JumpRateModel.sol/JumpRateModel.json";
import CTokenInterfacesArtifact from "../../../artifacts/contracts/compound/CTokenInterfaces.sol/CTokenInterface.json";

export default class JumpRateModelV2 implements InterestRateModel {
  static RUNTIME_BYTECODE_HASH = "0xc6df64d77d18236fa0e3a1bb939e979d14453af5c8287891decfb67710972c3c";

  initialized: boolean | undefined;
  baseRatePerBlock: BigNumber | undefined;
  multiplierPerBlock: BigNumber | undefined;
  jumpMultiplierPerBlock: BigNumber | undefined;
  kink: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;

  async init(interestRateModelAddress: string, assetAddress: string, provider: any) {
    const jumpRateModelContract = new Contract(
      interestRateModelAddress,
      JumpRateModelArtifact.abi,
      provider
    );

    this.baseRatePerBlock = BigNumber.from(await jumpRateModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = BigNumber.from(await jumpRateModelContract.callStatic.multiplierPerBlock());
    this.jumpMultiplierPerBlock = BigNumber.from(await jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
    this.kink = BigNumber.from(await jumpRateModelContract.callStatic.kink());

    const cTokenContract = new Contract(
      assetAddress,
      CTokenInterfacesArtifact.abi,
      provider
    );
    this.reserveFactorMantissa = BigNumber.from(await cTokenContract.callStatic.reserveFactorMantissa());
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(
      BigNumber.from(await cTokenContract.callStatic.adminFeeMantissa())
    );
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(
      BigNumber.from(await cTokenContract.callStatic.fuseFeeMantissa())
    );
    this.initialized = true;
  }

  async _init(
    interestRateModelAddress: string,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish,
    provider: Web3Provider,
  ) {
    const jumpRateModelContract = new Contract(
      interestRateModelAddress,
      JumpRateModelArtifact.abi,
      provider
    );
    this.baseRatePerBlock = BigNumber.from(await jumpRateModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = BigNumber.from(await jumpRateModelContract.callStatic.multiplierPerBlock());
    this.jumpMultiplierPerBlock = BigNumber.from(await jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
    this.kink = BigNumber.from(await jumpRateModelContract.callStatic.kink());

    this.reserveFactorMantissa = BigNumber.from(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(fuseFeeMantissa));

    this.initialized = true;
  }

  async __init(
    baseRatePerBlock: BigNumberish,
    multiplierPerBlock: BigNumberish,
    jumpMultiplierPerBlock: BigNumberish,
    kink: BigNumberish,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish
  ) {
    this.baseRatePerBlock = BigNumber.from(baseRatePerBlock);
    this.multiplierPerBlock = BigNumber.from(multiplierPerBlock);
    this.jumpMultiplierPerBlock = BigNumber.from(jumpMultiplierPerBlock);
    this.kink = BigNumber.from(kink);

    this.reserveFactorMantissa = BigNumber.from(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(fuseFeeMantissa));

    this.initialized = true;
  }

  getBorrowRate(utilizationRate: BigNumber): BigNumber {
    if (
      !this.initialized ||
      !this.multiplierPerBlock ||
      !this.kink ||
      !this.baseRatePerBlock ||
      !this.jumpMultiplierPerBlock
    )
      throw new Error("Interest rate model class not initialized.");
    if (utilizationRate.lte(this.kink)) {
      return utilizationRate.mul(this.multiplierPerBlock).div(BigNumber.from(1e18)).add(this.baseRatePerBlock);
    } else {
      const normalRate = this.kink.mul(this.multiplierPerBlock).div(BigNumber.from(1e18)).add(this.baseRatePerBlock);
      const excessUtil = utilizationRate.sub(this.kink);
      return excessUtil.mul(this.jumpMultiplierPerBlock).div(BigNumber.from(1e18)).add(normalRate);
    }
  }

  getSupplyRate(utilizationRate: BigNumber): BigNumber {
    if (!this.initialized || !this.reserveFactorMantissa) throw new Error("Interest rate model class not initialized.");
    const oneMinusReserveFactor = BigNumber.from(1e18).sub(this.reserveFactorMantissa);
    const borrowRate = this.getBorrowRate(utilizationRate);
    const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(BigNumber.from(1e18));
    return utilizationRate.mul(rateToPool).div(BigNumber.from(1e18));
  }
}
