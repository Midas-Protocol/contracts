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
const JumpRateModel_json_1 = __importDefault(require("../../../artifacts/contracts/compound/JumpRateModel.sol/JumpRateModel.json"));
const CTokenInterface_json_1 = __importDefault(require("../../../artifacts/contracts/compound/CTokenInterfaces.sol/CTokenInterface.json"));
class JumpRateModel {
    init(interestRateModelAddress, assetAddress, provider) {
        return __awaiter(this, void 0, void 0, function* () {
            const jumpRateModelContract = new ethers_1.Contract(interestRateModelAddress, JumpRateModel_json_1.default.abi, provider);
            this.baseRatePerBlock = ethers_1.BigNumber.from(yield jumpRateModelContract.callStatic.baseRatePerBlock());
            this.multiplierPerBlock = ethers_1.BigNumber.from(yield jumpRateModelContract.callStatic.multiplierPerBlock());
            this.jumpMultiplierPerBlock = ethers_1.BigNumber.from(yield jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
            this.kink = ethers_1.BigNumber.from(yield jumpRateModelContract.callStatic.kink());
            const cTokenContract = new ethers_1.Contract(assetAddress, CTokenInterface_json_1.default.abi, provider);
            this.reserveFactorMantissa = ethers_1.BigNumber.from(yield cTokenContract.callStatic.reserveFactorMantissa());
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(yield cTokenContract.callStatic.adminFeeMantissa()));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(yield cTokenContract.callStatic.fuseFeeMantissa()));
            this.initialized = true;
        });
    }
    _init(interestRateModelAddress, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa, provider) {
        return __awaiter(this, void 0, void 0, function* () {
            const jumpRateModelContract = new ethers_1.Contract(interestRateModelAddress, JumpRateModel_json_1.default.abi, provider);
            this.baseRatePerBlock = ethers_1.BigNumber.from(yield jumpRateModelContract.callStatic.baseRatePerBlock());
            this.multiplierPerBlock = ethers_1.BigNumber.from(yield jumpRateModelContract.callStatic.multiplierPerBlock());
            this.jumpMultiplierPerBlock = ethers_1.BigNumber.from(yield jumpRateModelContract.callStatic.jumpMultiplierPerBlock());
            this.kink = ethers_1.BigNumber.from(yield jumpRateModelContract.callStatic.kink());
            this.reserveFactorMantissa = ethers_1.BigNumber.from(reserveFactorMantissa);
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(adminFeeMantissa));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(fuseFeeMantissa));
            this.initialized = true;
        });
    }
    __init(baseRatePerBlock, multiplierPerBlock, jumpMultiplierPerBlock, kink, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa) {
        return __awaiter(this, void 0, void 0, function* () {
            this.baseRatePerBlock = ethers_1.BigNumber.from(baseRatePerBlock);
            this.multiplierPerBlock = ethers_1.BigNumber.from(multiplierPerBlock);
            this.jumpMultiplierPerBlock = ethers_1.BigNumber.from(jumpMultiplierPerBlock);
            this.kink = ethers_1.BigNumber.from(kink);
            this.reserveFactorMantissa = ethers_1.BigNumber.from(reserveFactorMantissa);
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(adminFeeMantissa));
            this.reserveFactorMantissa = this.reserveFactorMantissa.add(ethers_1.BigNumber.from(fuseFeeMantissa));
            this.initialized = true;
        });
    }
    getBorrowRate(utilizationRate) {
        if (!this.initialized ||
            !this.kink ||
            !this.multiplierPerBlock ||
            !this.baseRatePerBlock ||
            !this.jumpMultiplierPerBlock)
            throw new Error("Interest rate model class not initialized.");
        if (utilizationRate.lte(this.kink)) {
            return utilizationRate.mul(this.multiplierPerBlock).div(ethers_1.utils.parseEther("1")).add(this.baseRatePerBlock);
        }
        else {
            const normalRate = this.kink.mul(this.multiplierPerBlock).div(ethers_1.utils.parseEther("1")).add(this.baseRatePerBlock);
            const excessUtil = utilizationRate.sub(this.kink);
            return excessUtil.mul(this.jumpMultiplierPerBlock).div(ethers_1.utils.parseEther("1")).add(normalRate);
        }
    }
    getSupplyRate(utilizationRate) {
        if (!this.initialized || !this.reserveFactorMantissa)
            throw new Error("Interest rate model class not initialized.");
        const oneMinusReserveFactor = ethers_1.utils.parseEther("1").sub(this.reserveFactorMantissa);
        const borrowRate = this.getBorrowRate(utilizationRate);
        const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(ethers_1.utils.parseEther("1"));
        return utilizationRate.mul(rateToPool).div(ethers_1.utils.parseEther("1"));
    }
}
exports.default = JumpRateModel;
JumpRateModel.RUNTIME_BYTECODE_HASH = ethers_1.utils.keccak256(JumpRateModel_json_1.default.deployedBytecode);
