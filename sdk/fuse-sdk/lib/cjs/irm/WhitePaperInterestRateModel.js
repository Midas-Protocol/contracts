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
class WhitePaperInterestRateModel {
    init(interestRateModelAddress, assetAddress, provider) {
        return __awaiter(this, void 0, void 0, function* () {
            const whitePaperModelContract = (0, web3_1.createContract)(interestRateModelAddress, compound_protocol_min_json_1.contracts["contracts/WhitePaperInterestRateModel.sol:WhitePaperInterestRateModel"].abi, provider);
            this.baseRatePerBlock = (0, web3_1.toBN)(yield whitePaperModelContract.callStatic.baseRatePerBlock());
            this.multiplierPerBlock = (0, web3_1.toBN)(yield whitePaperModelContract.callStatic.multiplierPerBlock());
            const cTokenContract = (0, web3_1.createContract)(assetAddress, JSON.parse(compound_protocol_min_json_1.contracts["contracts/CTokenInterfaces.sol:CTokenInterface"].abi), provider);
            this.reserveFactorMantissa = (0, web3_1.toBN)(yield cTokenContract.callStatic.reserveFactorMantissa());
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(yield cTokenContract.callStatic.adminFeeMantissa()));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(yield cTokenContract.callStatic.fuseFeeMantissa()));
            this.initialized = true;
        });
    }
    _init(interestRateModelAddress, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa, provider) {
        return __awaiter(this, void 0, void 0, function* () {
            const whitePaperModelContract = (0, web3_1.createContract)(interestRateModelAddress, compound_protocol_min_json_1.contracts["contracts/WhitePaperInterestRateModel.sol:WhitePaperInterestRateModel"].abi, provider);
            this.baseRatePerBlock = (0, web3_1.toBN)(yield whitePaperModelContract.callStatic.baseRatePerBlock());
            this.multiplierPerBlock = (0, web3_1.toBN)(yield whitePaperModelContract.callStatic.multiplierPerBlock());
            this.reserveFactorMantissa = (0, web3_1.toBN)(reserveFactorMantissa);
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(adminFeeMantissa));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(fuseFeeMantissa));
            this.initialized = true;
        });
    }
    __init(baseRatePerBlock, multiplierPerBlock, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa) {
        return __awaiter(this, void 0, void 0, function* () {
            this.baseRatePerBlock = (0, web3_1.toBN)(baseRatePerBlock);
            this.multiplierPerBlock = (0, web3_1.toBN)(multiplierPerBlock);
            this.reserveFactorMantissa = (0, web3_1.toBN)(reserveFactorMantissa);
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(adminFeeMantissa));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add((0, web3_1.toBN)(fuseFeeMantissa));
            this.initialized = true;
        });
    }
    getBorrowRate(utilizationRate) {
        if (!this.initialized || !this.multiplierPerBlock || !this.baseRatePerBlock)
            throw new Error("Interest rate model class not initialized.");
        return utilizationRate.mul(this.multiplierPerBlock).div((0, web3_1.toBN)(1e18)).add(this.baseRatePerBlock);
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
exports.default = WhitePaperInterestRateModel;
WhitePaperInterestRateModel.RUNTIME_BYTECODE_HASH = "0xe3164248fb86cce0eb8037c9a5c8d05aac2b2ebdb46741939be466a7b17d0b83";
