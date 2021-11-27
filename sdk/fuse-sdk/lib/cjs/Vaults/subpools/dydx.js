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
const axios_1 = __importDefault(require("axios"));
const ethers_1 = require("ethers");
class DydxSubpool {
    constructor(provider) {
        this.provider = provider;
        this.cache = new cache_1.default({
            dydxCurrencyApys: 300,
        });
    }
    getCurrencyApys() {
        return __awaiter(this, void 0, void 0, function* () {
            return yield this.cache.getOrUpdate("dydxCurrencyApys", function () {
                return __awaiter(this, void 0, void 0, function* () {
                    const data = (yield axios_1.default.get("https://api.dydx.exchange/v1/markets")).data;
                    let apyBNs = {};
                    for (let i = 0; i < data.markets.length; i++) {
                        apyBNs[data.markets[i].symbol] = ethers_1.utils.parseUnits(data.markets[i].totalSupplyAPR, 77);
                    }
                    return apyBNs;
                });
            });
        });
    }
}
exports.default = DydxSubpool;
