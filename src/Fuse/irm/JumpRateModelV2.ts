import { BigNumber, BigNumberish } from "ethers";
import { createContract, toBN } from "../utils/web3";
import contracts from "../contracts/compound-protocol.json";
import { Web3Provider } from "@ethersproject/providers";

export default class JumpRateModelV2 {
  static RUNTIME_BYTECODE_HASH = "0xc6df64d77d18236fa0e3a1bb939e979d14453af5c8287891decfb67710972c3c";

  initialized: boolean | undefined;
  baseRatePerBlock: BigNumber | undefined;
  multiplierPerBlock: BigNumber | undefined;
  jumpMultiplierPerBlock: BigNumber | undefined;
  kink: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;

  async init(interestRateModelAddress: string, assetAddress: string, provider: any) {
    const jumpRateModelContract = createContract(
      interestRateModelAddress,
      contracts.contracts["contracts/JumpRateModel.sol:JumpRateModel"].abi,
      provider
    );

    this.baseRatePerBlock = toBN(await jumpRateModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = toBN(await jumpRateModelContract.callStatic.multiplierPerBlock());
    this.jumpMultiplierPerBlock = toBN(await jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
    this.kink = toBN(await jumpRateModelContract.callStatic.kink());

    const cTokenContract = createContract(
      assetAddress,
      contracts.contracts["contracts/CTokenInterfaces.sol:CTokenInterface"].abi,
      provider
    );
    this.reserveFactorMantissa = toBN(await cTokenContract.callStatic.reserveFactorMantissa());
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(
      toBN(await cTokenContract.callStatic.adminFeeMantissa())
    );
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(
      toBN(await cTokenContract.callStatic.fuseFeeMantissa())
    );
    this.initialized = true;
  }

  async _init(
    provider: Web3Provider,
    interestRateModelAddress: string,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish
  ) {
    const jumpRateModelContract = createContract(
      interestRateModelAddress,
      contracts.contracts["contracts/JumpRateModel.sol:JumpRateModel"].abi,
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
    fuseFeeMantissa: BigNumberish
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
    if (
      !this.initialized ||
      !this.multiplierPerBlock ||
      !this.kink ||
      !this.baseRatePerBlock ||
      !this.jumpMultiplierPerBlock
    )
      throw new Error("Interest rate model class not initialized.");
    if (utilizationRate.lte(this.kink)) {
      return utilizationRate.mul(this.multiplierPerBlock).div(toBN(1e18)).add(this.baseRatePerBlock);
    } else {
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
