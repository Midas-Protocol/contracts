import { BigNumber, BigNumberish } from "ethers";
import { createContract, toBN } from "../utils/web3";
import { contracts } from "../contracts/compound-protocol.min.json";
import { Web3Provider } from "@ethersproject/providers";

export default class WhitePaperInterestRateModel {
  static RUNTIME_BYTECODE_HASH = "0xe3164248fb86cce0eb8037c9a5c8d05aac2b2ebdb46741939be466a7b17d0b83";
  initialized: boolean | undefined;
  baseRatePerBlock: BigNumber | undefined;
  multiplierPerBlock: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;


  async init(interestRateModelAddress: string, assetAddress: string, provider: any) {
    const whitePaperModelContract = createContract(
      interestRateModelAddress,
      contracts["contracts/WhitePaperInterestRateModel.sol:WhitePaperInterestRateModel"].abi,
      provider
    );

    this.baseRatePerBlock = toBN(await whitePaperModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = toBN(await whitePaperModelContract.callStatic.multiplierPerBlock());

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
    const whitePaperModelContract = createContract(
      interestRateModelAddress,
      contracts["contracts/WhitePaperInterestRateModel.sol:WhitePaperInterestRateModel"].abi,
      provider
    );

    this.baseRatePerBlock = toBN(await whitePaperModelContract.callStatic.baseRatePerBlock());
    this.multiplierPerBlock = toBN(await whitePaperModelContract.callStatic.multiplierPerBlock());

    this.reserveFactorMantissa = toBN(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(toBN(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(toBN(fuseFeeMantissa));

    this.initialized = true;
  }

  async __init(
    baseRatePerBlock: BigNumberish,
    multiplierPerBlock: BigNumberish,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish,
  ) {
    this.baseRatePerBlock = toBN(baseRatePerBlock);
    this.multiplierPerBlock = toBN(multiplierPerBlock);

    this.reserveFactorMantissa = toBN(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(toBN(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(toBN(fuseFeeMantissa));
    this.initialized = true;
  }

  getBorrowRate(utilizationRate: BigNumber) {
    if (!this.initialized || !this.multiplierPerBlock || !this.baseRatePerBlock) throw new Error("Interest rate model class not initialized.");
    return utilizationRate.mul(this.multiplierPerBlock).div(toBN(1e18)).add(this.baseRatePerBlock);
  }

  getSupplyRate(utilizationRate: BigNumber): BigNumber {
    if (!this.initialized || !this.reserveFactorMantissa) throw new Error("Interest rate model class not initialized.");

    const oneMinusReserveFactor = toBN(1e18).sub(this.reserveFactorMantissa);
    const borrowRate = this.getBorrowRate(utilizationRate);
    const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(toBN(1e18));
    return utilizationRate.mul(rateToPool).div(toBN(1e18));
  }
}
