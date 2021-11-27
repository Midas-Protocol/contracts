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
const cache_1 = __importDefault(require("../cache"));
// ABIs
const Bank_json_1 = __importDefault(require("./alpha/abi/Bank.json"));
const ConfigurableInterestBankConfig_json_1 = __importDefault(require("./alpha/abi/ConfigurableInterestBankConfig.json"));
const externalContractAddressesAlpha = {
    Bank: "0x67B66C99D3Eb37Fa76Aa3Ed1ff33E8e39F0b9c7A",
    ConfigurableInterestBankConfig: "0x97a49f8eec63c0dfeb9db4c791229477962dc692",
};
const externalAbisAlpha = {
    Bank: Bank_json_1.default,
    ConfigurableInterestBankConfig: ConfigurableInterestBankConfig_json_1.default,
};
class AlphaSubpool {
    constructor(provider) {
        this.provider = provider;
        this.cache = new cache_1.default({
            alphaIBEthApy: 300,
        });
        this.externalContracts = {};
        for (const contractName of Object.keys(externalContractAddressesAlpha)) {
            this.externalContracts[contractName] = new ethers_1.Contract(externalContractAddressesAlpha[contractName], externalAbisAlpha[contractName], this.provider);
        }
    }
    getCurrencyApys() {
        return __awaiter(this, void 0, void 0, function* () {
            return { ETH: yield this.getIBEthApyBN() };
        });
    }
    getIBEthApyBN() {
        return __awaiter(this, void 0, void 0, function* () {
            let self = this;
            return yield this.cache.getOrUpdate("alphaIBEthApy", function () {
                return __awaiter(this, void 0, void 0, function* () {
                    try {
                        const glbDebtVal = yield self.externalContracts.Bank.glbDebtVal();
                        const balance = yield self.provider.getBalance(self.externalContracts.Bank.address);
                        // as this is no longer being used I'll leave it as is
                        const interestRatePerSecondBN = yield self.externalContracts.ConfigurableInterestBankConfig.callStatic.getInterestRate(glbDebtVal, balance);
                        return balance;
                    }
                    catch (e) {
                        throw new Error("Failed to get Alpha Homora V1 interest rate: " + e);
                    }
                });
            });
        });
    }
}
exports.default = AlphaSubpool;
