"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const ethers_1 = require("ethers");
class YVault {
    constructor(provider) {
        this.provider = provider;
    }
    getCurrencyApys() {
        return {
            DAI: ethers_1.constants.Zero,
            USDC: ethers_1.constants.Zero,
            USDT: ethers_1.constants.Zero,
            TUSD: ethers_1.constants.Zero,
        };
    }
}
exports.default = YVault;
