"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const web3_1 = require("../utils/web3");
const compound_protocol_min_json_1 = require("../contracts/compound-protocol.min.json");
class JumpRateModel {
    init(interestRateModelAddress, assetAddress, provider) {
        return __awaiter(this, void 0, void 0, function* () {
            const jumpRateModelContract = (0, web3_1.createContract)(interestRateModelAddress, compound_protocol_min_json_1.contracts["contracts/JumpRateModel.sol:JumpRateModel"].abi, provider);
            this.baseRatePerBlock = (0, web3_1.toBN)(yield jumpRateModelContract.callStatic.baseRatePerBlock());
            this.multiplierPerBlock = (0, web3_1.toBN)(yield jumpRateModelContract.callStatic.multiplierPerBlock());
            this.jumpMultiplierPerBlock = (0, web3_1.toBN)(yield jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
            this.kink = (0, web3_1.toBN)(yield jumpRateModelContract.callStatic.kink());
            const cTokenContract = (0, web3_1.createContract)(assetAddress, JSON.parse(compound_protocol_min_json_1.contracts["contracts/CTokenInterfaces.sol:CTokenInterface"].abi), provider);
            this.reserveFactorMantissa = (0, web3_1.toBN)(yield cTokenContract.callStatic.reserveFactorMantissa());
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(yield cTokenContract.callStatic.adminFeeMantissa()));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(yield cTokenContract.callStatic.fuseFeeMantissa()));
            this.initialized = true;
        });
    }
    _init(interestRateModelAddress, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa, provider) {
        return __awaiter(this, void 0, void 0, function* () {
            const jumpRateModelContract = (0, web3_1.createContract)(interestRateModelAddress, compound_protocol_min_json_1.contracts["contracts/JumpRateModel.sol:JumpRateModel"].abi, provider);
            this.baseRatePerBlock = (0, web3_1.toBN)(yield jumpRateModelContract.callStatic.baseRatePerBlock());
            this.multiplierPerBlock = (0, web3_1.toBN)(yield jumpRateModelContract.callStatic.multiplierPerBlock());
            this.jumpMultiplierPerBlock = (0, web3_1.toBN)(yield jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
            this.kink = (0, web3_1.toBN)(yield jumpRateModelContract.callStatic.kink());
            this.reserveFactorMantissa = (0, web3_1.toBN)(reserveFactorMantissa);
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(adminFeeMantissa));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(fuseFeeMantissa));
            this.initialized = true;
        });
    }
    __init(baseRatePerBlock, multiplierPerBlock, jumpMultiplierPerBlock, kink, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa) {
        return __awaiter(this, void 0, void 0, function* () {
            this.baseRatePerBlock = (0, web3_1.toBN)(baseRatePerBlock);
            this.multiplierPerBlock = (0, web3_1.toBN)(multiplierPerBlock);
            this.jumpMultiplierPerBlock = (0, web3_1.toBN)(jumpMultiplierPerBlock);
            this.kink = (0, web3_1.toBN)(kink);
            this.reserveFactorMantissa = (0, web3_1.toBN)(reserveFactorMantissa);
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(adminFeeMantissa));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(fuseFeeMantissa));
            this.initialized = true;
        });
    }
    getBorrowRate(utilizationRate) {
        if (!this.initialized || !this.kink || !this.multiplierPerBlock || !this.baseRatePerBlock || !this.jumpMultiplierPerBlock)
            throw new Error("Interest rate model class not initialized.");
        if (utilizationRate.lte(this.kink)) {
            return utilizationRate.mul(this.multiplierPerBlock).div((0, web3_1.toBN)(1e18)).add(this.baseRatePerBlock);
        }
        else {
            const normalRate = this.kink.mul(this.multiplierPerBlock).div((0, web3_1.toBN)(1e18)).add(this.baseRatePerBlock);
            const excessUtil = utilizationRate.sub(this.kink);
            return excessUtil.mul(this.jumpMultiplierPerBlock).div((0, web3_1.toBN)(1e18)).add(normalRate);
        }
    }
    getSupplyRate(utilizationRate) {
        if (!this.initialized || !this.reserveFactorMantissa)
            throw new Error("Interest rate model class not initialized.");
        const oneMinusReserveFactor = (0, web3_1.toBN)(1e18).sub(this.reserveFactorMantissa);
        const borrowRate = this.getBorrowRate(utilizationRate);
        const rateToPool = borrowRate.mul(oneMinusReserveFactor).div((0, web3_1.toBN)(1e18));
        return utilizationRate.mul(rateToPool).div((0, web3_1.toBN)(1e18));
    }
}
exports.default = JumpRateModel;
JumpRateModel.RUNTIME_BYTECODE_HASHES = [
    "0x00f083d6c0022358b6b3565c026e815cfd6fc9dcd6c3ad1125e72cbb81f41b2a",
    "0x47d7a0e70c9e049792bb96abf3c7527c7543154450c6267f31b52e2c379badc7"
];
