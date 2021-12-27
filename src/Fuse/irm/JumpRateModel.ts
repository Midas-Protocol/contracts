import { BigNumberish, BigNumber, Contract } from "ethers";
import { Web3Provider } from "@ethersproject/providers";

import { InterestRateModel } from "./InterestRateModel";
import contracts from "../contracts/compound-protocol.json";

export default class JumpRateModel implements InterestRateModel {
  static RUNTIME_BYTECODE_HASHES = [
    "0x00f083d6c0022358b6b3565c026e815cfd6fc9dcd6c3ad1125e72cbb81f41b2a",
    "0x47d7a0e70c9e049792bb96abf3c7527c7543154450c6267f31b52e2c379badc7",
  ];

  initialized: boolean | undefined;
  baseRatePerBlock: BigNumber | undefined;
  multiplierPerBlock: BigNumber | undefined;
  jumpMultiplierPerBlock: BigNumber | undefined;
  kink: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;
  RUNTIME_BYTECODE_HASHES: any;

  async init(interestRateModelAddress: string, assetAddress: string, provider: Web3Provider): Promise<void> {
    const jumpRateModelContract = new Contract(
      interestRateModelAddress,
      contracts.contracts["contracts/JumpRateModel.sol:JumpRateModel"].abi,
      provider
    );
    this.baseRatePerBlock = BigNumber.from(await jumpRateModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = BigNumber.from(await jumpRateModelContract.callStatic.multiplierPerBlock());
    this.jumpMultiplierPerBlock = BigNumber.from(await jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
    this.kink = BigNumber.from(await jumpRateModelContract.callStatic.kink());

    const cTokenContract = new Contract(
      assetAddress,
      contracts.contracts["contracts/CTokenInterfaces.sol:CTokenInterface"].abi,
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
    provider: Web3Provider
  ): Promise<void> {
    const jumpRateModelContract = new Contract(
      interestRateModelAddress,
      contracts.contracts["contracts/JumpRateModel.sol:JumpRateModel"].abi,
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

  getBorrowRate(utilizationRate: BigNumber) {
    if (
      !this.initialized ||
      !this.kink ||
      !this.multiplierPerBlock ||
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

  getSupplyRate(utilizationRate: BigNumber) {
    if (!this.initialized || !this.reserveFactorMantissa) throw new Error("Interest rate model class not initialized.");
    const oneMinusReserveFactor = BigNumber.from(1e18).sub(this.reserveFactorMantissa);
    const borrowRate = this.getBorrowRate(utilizationRate);
    const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(BigNumber.from(1e18));
    return utilizationRate.mul(rateToPool).div(BigNumber.from(1e18));
  }
}
