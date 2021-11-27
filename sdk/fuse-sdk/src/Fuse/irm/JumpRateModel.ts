import { BigNumberish, BigNumber } from "ethers";
import { createContract, toBN } from "../utils/web3";
import { contracts } from "../contracts/compound-protocol.min.json";
import { Web3Provider } from "@ethersproject/providers";

export interface JumpRateModelInterface {
   JumpRateModel
}

export default class JumpRateModel {
  static RUNTIME_BYTECODE_HASHES = [
    "0x00f083d6c0022358b6b3565c026e815cfd6fc9dcd6c3ad1125e72cbb81f41b2a",
    "0x47d7a0e70c9e049792bb96abf3c7527c7543154450c6267f31b52e2c379badc7"
  ];
  
  initialized: boolean | undefined;
  baseRatePerBlock: BigNumber | undefined;
  multiplierPerBlock: BigNumber | undefined;
  jumpMultiplierPerBlock: BigNumber | undefined;
  kink: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;
  RUNTIME_BYTECODE_HASHES

  async init(interestRateModelAddress: string, assetAddress: string, provider: any) {
    const jumpRateModelContract = createContract(
      interestRateModelAddress,
      contracts["contracts/JumpRateModel.sol:JumpRateModel"].abi,
      provider
    );
    this.baseRatePerBlock = toBN(await jumpRateModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = toBN(await jumpRateModelContract.callStatic.multiplierPerBlock());
    this.jumpMultiplierPerBlock = toBN(await jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
    this.kink = toBN(await jumpRateModelContract.callStatic.kink());
    
    const cTokenContract = createContract(
      assetAddress,
      JSON.parse(contracts["contracts/CTokenInterfaces.sol:CTokenInterface"].abi),
      provider
    );
    this.reserveFactorMantissa = toBN(await cTokenContract.callStatic.reserveFactorMantissa());
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(
      toBN(await cTokenContract.callStatic.adminFeeMantissa()),
    );
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(
      toBN(await cTokenContract.callStatic.fuseFeeMantissa()),
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
    const jumpRateModelContract = createContract(
      interestRateModelAddress,
      contracts["contracts/JumpRateModel.sol:JumpRateModel"].abi,
      provider
    );
    this.baseRatePerBlock = toBN(await jumpRateModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = toBN(await jumpRateModelContract.callStatic.multiplierPerBlock());
    this.jumpMultiplierPerBlock = toBN(await jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
    this.kink = toBN(await jumpRateModelContract.callStatic.kink());

    this.reserveFactorMantissa = toBN(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(toBN(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(toBN(fuseFeeMantissa));

    this.initialized = true;
  }

  async __init(
    baseRatePerBlock: BigNumberish,
    multiplierPerBlock: BigNumberish,
    jumpMultiplierPerBlock: BigNumberish,
    kink: BigNumberish,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish,
  ) {
    this.baseRatePerBlock = toBN(baseRatePerBlock);
    this.multiplierPerBlock = toBN(multiplierPerBlock);
    this.jumpMultiplierPerBlock = toBN(jumpMultiplierPerBlock);
    this.kink = toBN(kink);

    this.reserveFactorMantissa = toBN(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(toBN(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(toBN(fuseFeeMantissa));

    this.initialized = true;
  }

  getBorrowRate(utilizationRate: BigNumber) {
    if (!this.initialized || !this.kink || !this.multiplierPerBlock || !this.baseRatePerBlock || !this.jumpMultiplierPerBlock) throw new Error("Interest rate model class not initialized.");
    if (utilizationRate.lte(this.kink)) {
      return utilizationRate.mul(this.multiplierPerBlock).div(toBN(1e18)).add(this.baseRatePerBlock);
    } 
    else {
      const normalRate = this.kink.mul(this.multiplierPerBlock).div(toBN(1e18)).add(this.baseRatePerBlock);
      const excessUtil = utilizationRate.sub(this.kink);
      return excessUtil.mul(this.jumpMultiplierPerBlock).div(toBN(1e18)).add(normalRate);
    }
  }

  getSupplyRate(utilizationRate: BigNumber) {
    if (!this.initialized || !this.reserveFactorMantissa) throw new Error("Interest rate model class not initialized.");
    const oneMinusReserveFactor = toBN(1e18).sub(this.reserveFactorMantissa);
    const borrowRate = this.getBorrowRate(utilizationRate);
    const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(toBN(1e18));
    return utilizationRate.mul(rateToPool).div(toBN(1e18));
  }
}
