import { BigNumber, BigNumberish, Contract } from "ethers";
import { Web3Provider } from "@ethersproject/providers";
import { InterestRateModel } from "./InterestRateModel";

import contracts from "../contracts/compound-protocol.json";

export default class WhitePaperInterestRateModel implements InterestRateModel {
  static RUNTIME_BYTECODE_HASH = "0xe3164248fb86cce0eb8037c9a5c8d05aac2b2ebdb46741939be466a7b17d0b83";
  initialized: boolean | undefined;
  baseRatePerBlock: BigNumber | undefined;
  multiplierPerBlock: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;

  async init(interestRateModelAddress: string, assetAddress: string, provider: any) {
    const whitePaperModelContract = new Contract(
      interestRateModelAddress,
      contracts.contracts["contracts/WhitePaperInterestRateModel.sol:WhitePaperInterestRateModel"].abi,
      provider
    );

    this.baseRatePerBlock = BigNumber.from(await whitePaperModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = BigNumber.from(await whitePaperModelContract.callStatic.multiplierPerBlock());

    const cTokenContract = new Contract(
      assetAddress,
      JSON.parse(contracts["contracts/CTokenInterfaces.sol:CTokenInterface"].abi),
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
  ) {
    const whitePaperModelContract = new Contract(
      interestRateModelAddress,
      contracts.contracts["contracts/WhitePaperInterestRateModel.sol:WhitePaperInterestRateModel"].abi,
      provider
    );

    this.baseRatePerBlock = BigNumber.from(await whitePaperModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = BigNumber.from(await whitePaperModelContract.callStatic.multiplierPerBlock());

    this.reserveFactorMantissa = BigNumber.from(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(fuseFeeMantissa));

    this.initialized = true;
  }

  async __init(
    baseRatePerBlock: BigNumberish,
    multiplierPerBlock: BigNumberish,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish
  ) {
    this.baseRatePerBlock = BigNumber.from(baseRatePerBlock);
    this.multiplierPerBlock = BigNumber.from(multiplierPerBlock);

    this.reserveFactorMantissa = BigNumber.from(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(fuseFeeMantissa));
    this.initialized = true;
  }

  getBorrowRate(utilizationRate: BigNumber) {
    if (!this.initialized || !this.multiplierPerBlock || !this.baseRatePerBlock)
      throw new Error("Interest rate model class not initialized.");
    return utilizationRate.mul(this.multiplierPerBlock).div(BigNumber.from(1e18)).add(this.baseRatePerBlock);
  }

  getSupplyRate(utilizationRate: BigNumber): BigNumber {
    if (!this.initialized || !this.reserveFactorMantissa) throw new Error("Interest rate model class not initialized.");

    const oneMinusReserveFactor = BigNumber.from(1e18).sub(this.reserveFactorMantissa);
    const borrowRate = this.getBorrowRate(utilizationRate);
    const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(BigNumber.from(1e18));
    return utilizationRate.mul(rateToPool).div(BigNumber.from(1e18));
  }
}
