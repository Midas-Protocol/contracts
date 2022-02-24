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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const ethers_1 = require("ethers");
const WhitePaperInterestRateModel_json_1 = __importDefault(require("../../../artifacts/contracts/compound/WhitePaperInterestRateModel.sol/WhitePaperInterestRateModel.json"));
const CTokenInterface_json_1 = __importDefault(require("../../../artifacts/contracts/compound/CTokenInterfaces.sol/CTokenInterface.json"));
class WhitePaperInterestRateModel {
    init(interestRateModelAddress, assetAddress, provider) {
        return __awaiter(this, void 0, void 0, function* () {
            const whitePaperModelContract = new ethers_1.Contract(interestRateModelAddress, WhitePaperInterestRateModel_json_1.default.abi, provider);
            this.baseRatePerBlock = ethers_1.BigNumber.from(yield whitePaperModelContract.callStatic.baseRatePerBlock());
            this.multiplierPerBlock = ethers_1.BigNumber.from(yield whitePaperModelContract.callStatic.multiplierPerBlock());
            const cTokenContract = new ethers_1.Contract(assetAddress, CTokenInterface_json_1.default.abi, provider);
            this.reserveFactorMantissa = ethers_1.BigNumber.from(yield cTokenContract.callStatic.reserveFactorMantissa());
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(yield cTokenContract.callStatic.adminFeeMantissa()));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(yield cTokenContract.callStatic.fuseFeeMantissa()));
            this.initialized = true;
        });
    }
    _init(interestRateModelAddress, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa, provider) {
        return __awaiter(this, void 0, void 0, function* () {
            console.log(interestRateModelAddress, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa, provider, "IRMMMMMM PARAMS WPIRM");
            const whitePaperModelContract = new ethers_1.Contract(interestRateModelAddress, WhitePaperInterestRateModel_json_1.default.abi, provider);
            this.baseRatePerBlock = ethers_1.BigNumber.from(yield whitePaperModelContract.callStatic.baseRatePerBlock());
            this.multiplierPerBlock = ethers_1.BigNumber.from(yield whitePaperModelContract.callStatic.multiplierPerBlock());
            this.reserveFactorMantissa = ethers_1.BigNumber.from(reserveFactorMantissa);
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(adminFeeMantissa));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(fuseFeeMantissa));
            this.initialized = true;
        });
    }
    __init(baseRatePerBlock, multiplierPerBlock, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa) {
        return __awaiter(this, void 0, void 0, function* () {
            this.baseRatePerBlock = ethers_1.BigNumber.from(baseRatePerBlock);
            this.multiplierPerBlock = ethers_1.BigNumber.from(multiplierPerBlock);
            this.reserveFactorMantissa = ethers_1.BigNumber.from(reserveFactorMantissa);
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(adminFeeMantissa));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(fuseFeeMantissa));
            this.initialized = true;
        });
    }
    getBorrowRate(utilizationRate) {
        if (!this.initialized || !this.multiplierPerBlock || !this.baseRatePerBlock)
            throw new Error("Interest rate model class not initialized.");
        return utilizationRate.mul(this.multiplierPerBlock).div(ethers_1.BigNumber.from(1e18)).add(this.baseRatePerBlock);
    }
    getSupplyRate(utilizationRate) {
        if (!this.initialized || !this.reserveFactorMantissa)
            throw new Error("Interest rate model class not initialized.");
        const oneMinusReserveFactor = ethers_1.BigNumber.from(1e18).sub(this.reserveFactorMantissa);
        const borrowRate = this.getBorrowRate(utilizationRate);
        const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(ethers_1.BigNumber.from(1e18));
        return utilizationRate.mul(rateToPool).div(ethers_1.BigNumber.from(1e18));
    }
}
exports.default = WhitePaperInterestRateModel;
WhitePaperInterestRateModel.RUNTIME_BYTECODE_HASH = ethers_1.utils.keccak256(WhitePaperInterestRateModel_json_1.default.deployedBytecode);
