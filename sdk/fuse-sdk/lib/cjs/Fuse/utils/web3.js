"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.toBN = exports.createContract = void 0;
const ethers_1 = require("ethers");
const createContract = (address, abi, provider) => new ethers_1.Contract(address, abi, provider);
exports.createContract = createContract;
const toBN = (input) => {
    if (input === 0 || input === "0")
        return ethers_1.constants.Zero;
    if (input === 1e18)
        return ethers_1.constants.WeiPerEther;
    else
        return ethers_1.BigNumber.from(input);
};
exports.toBN = toBN;
