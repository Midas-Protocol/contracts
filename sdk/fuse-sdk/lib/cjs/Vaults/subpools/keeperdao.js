"use strict";
/* eslint-disable */
Object.defineProperty(exports, "__esModule", { value: true });
const ethers_1 = require("ethers");
class KeeperDAOSubpool {
    constructor(provider) {
        this.getCurrencyApys = () => {
            // TODO: KeeperDAO APYs
            return {
                ETH: ethers_1.constants.Zero,
            };
        };
        this.provider = provider;
    }
}
exports.default = KeeperDAOSubpool;
