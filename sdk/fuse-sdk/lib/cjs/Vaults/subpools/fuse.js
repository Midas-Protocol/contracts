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
const cache_1 = __importDefault(require("../cache"));
const ethers_1 = require("ethers");
// ABIs
const CErc20Delegate_json_1 = __importDefault(require("./fuse/abi/CErc20Delegate.json"));
class FuseSubpool {
    constructor(provider, cTokens) {
        this.provider = provider;
        this.cTokens = cTokens;
        this.cache = new cache_1.default({
            currencyApys: 300,
        });
    }
    getCurrencyApy(cTokenAddress) {
        return __awaiter(this, void 0, void 0, function* () {
            const cToken = new ethers_1.Contract(cTokenAddress, CErc20Delegate_json_1.default, this.provider);
            const supplyRatePerBlock = yield cToken.supplyRatePerBlock();
            return ethers_1.BigNumber.from(((Math.pow((supplyRatePerBlock / 1e18) * (4 * 60 * 24) + 1, 365) - 1) * 1e18).toFixed(0));
        });
    }
    getCurrencyApys() {
        return __awaiter(this, void 0, void 0, function* () {
            let self = this;
            return yield self.cache.getOrUpdate("currencyApys", function () {
                return __awaiter(this, void 0, void 0, function* () {
                    let apyBNs = {};
                    for (const currencyCode of Object.keys(self.cTokens)) {
                        apyBNs[currencyCode] = yield self.getCurrencyApy(self.cTokens[currencyCode]);
                    }
                    return apyBNs;
                });
            });
        });
    }
}
exports.default = FuseSubpool;
