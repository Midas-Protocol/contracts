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
const JumpRateModel_js_1 = __importDefault(require("./JumpRateModel.js"));
const ethers_1 = require("ethers");
const DAIInterestRateModelV2_json_1 = __importDefault(require("../../../artifacts/contracts/compound/DAIInterestRateModelV2.sol/DAIInterestRateModelV2.json"));
const CTokenInterface_json_1 = __importDefault(require("../../../artifacts/contracts/compound/CTokenInterfaces.sol/CTokenInterface.json"));
class DAIInterestRateModelV2 extends JumpRateModel_js_1.default {
    init(interestRateModelAddress, assetAddress, provider) {
        const _super = Object.create(null, {
            init: { get: () => super.init }
        });
        return __awaiter(this, void 0, void 0, function* () {
            yield _super.init.call(this, interestRateModelAddress, assetAddress, provider);
            const interestRateContract = new ethers_1.Contract(interestRateModelAddress, DAIInterestRateModelV2_json_1.default.abi, provider);
            this.dsrPerBlock = ethers_1.BigNumber.from(yield interestRateContract.callStatic.dsrPerBlock());
            const cTokenContract = new ethers_1.Contract(assetAddress, CTokenInterface_json_1.default.abi, provider);
            this.cash = ethers_1.BigNumber.from(yield cTokenContract.callStatic.getCash());
            this.borrows = ethers_1.BigNumber.from(yield cTokenContract.callStatic.totalBorrowsCurrent());
            this.reserves = ethers_1.BigNumber.from(yield cTokenContract.callStatic.totalReserves());
        });
    }
    _init(interestRateModelAddress, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa, provider) {
        const _super = Object.create(null, {
            _init: { get: () => super._init }
        });
        return __awaiter(this, void 0, void 0, function* () {
            yield _super._init.call(this, interestRateModelAddress, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa, provider);
            const interestRateContract = new ethers_1.Contract(interestRateModelAddress, DAIInterestRateModelV2_json_1.default.abi, provider);
            this.dsrPerBlock = ethers_1.BigNumber.from(yield interestRateContract.callStatic.dsrPerBlock());
            this.cash = ethers_1.BigNumber.from(0);
            this.borrows = ethers_1.BigNumber.from(0);
            this.reserves = ethers_1.BigNumber.from(0);
        });
    }
    __init(baseRatePerBlock, multiplierPerBlock, jumpMultiplierPerBlock, kink, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa) {
        const _super = Object.create(null, {
            __init: { get: () => super.__init }
        });
        return __awaiter(this, void 0, void 0, function* () {
            yield _super.__init.call(this, baseRatePerBlock, multiplierPerBlock, jumpMultiplierPerBlock, kink, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa);
            this.dsrPerBlock = ethers_1.BigNumber.from(0); // TODO: Make this work if DSR ever goes positive again
            this.cash = ethers_1.BigNumber.from(0);
            this.borrows = ethers_1.BigNumber.from(0);
            this.reserves = ethers_1.BigNumber.from(0);
        });
    }
    getSupplyRate(utilizationRate) {
        if (!this.initialized || !this.cash || !this.borrows || !this.reserves || !this.dsrPerBlock)
            throw new Error("Interest rate model class not initialized.");
        // const protocolRate = super.getSupplyRate(utilizationRate, this.reserveFactorMantissa); //todo - do we need this
        const protocolRate = super.getSupplyRate(utilizationRate);
        const underlying = this.cash.add(this.borrows).sub(this.reserves);
        if (underlying.isZero()) {
            return protocolRate;
        }
        else {
            const cashRate = this.cash.mul(this.dsrPerBlock).div(underlying);
            return cashRate.add(protocolRate);
        }
    }
}
exports.default = DAIInterestRateModelV2;
DAIInterestRateModelV2.RUNTIME_BYTECODE_HASH = ethers_1.utils.keccak256(DAIInterestRateModelV2_json_1.default.deployedBytecode);
