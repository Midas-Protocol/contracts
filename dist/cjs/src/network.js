"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.irmConfig = exports.oracleConfig = exports.chainOracles = exports.chainSpecificAddresses = exports.SupportedChains = void 0;
var SupportedChains;
(function (SupportedChains) {
    SupportedChains[SupportedChains["bsc"] = 56] = "bsc";
    SupportedChains[SupportedChains["chapel"] = 97] = "chapel";
    SupportedChains[SupportedChains["ganache"] = 1337] = "ganache";
    SupportedChains[SupportedChains["aurora"] = 1313161555] = "aurora";
    SupportedChains[SupportedChains["harmony"] = 1666600000] = "harmony";
})(SupportedChains = exports.SupportedChains || (exports.SupportedChains = {}));
exports.chainSpecificAddresses = {
    [SupportedChains.ganache]: {
        DAI_POT: "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",
        DAI_JUG: "0x19c0976f590d67707e62397c87829d896dc0f1f1",
        USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        W_TOKEN: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
        W_TOKEN_USD_CHAINLINK_PRICE_FEED: "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419", // use mainnet
    },
    [SupportedChains.chapel]: {
        DAI_POT: "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",
        DAI_JUG: "0x19c0976f590d67707e62397c87829d896dc0f1f1",
        USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        W_TOKEN: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
        W_TOKEN_USD_CHAINLINK_PRICE_FEED: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
    },
    [SupportedChains.bsc]: {
        DAI_POT: "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",
        DAI_JUG: "0x19c0976f590d67707e62397c87829d896dc0f1f1",
        USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        W_TOKEN: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
        W_TOKEN_USD_CHAINLINK_PRICE_FEED: "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419",
    },
};
const OracleTypes = {
    MasterPriceOracle: "MasterPriceOracle",
    SimplePriceOracle: "SimplePriceOracle",
    ChainlinkPriceOracleV2: "ChainlinkPriceOracleV2",
    UniswapTwapPriceOracleV2: "UniswapTwapPriceOracleV2",
};
exports.chainOracles = {
    [SupportedChains.ganache]: [OracleTypes.SimplePriceOracle, OracleTypes.MasterPriceOracle],
    [SupportedChains.chapel]: [
        OracleTypes.MasterPriceOracle,
        OracleTypes.ChainlinkPriceOracleV2,
        OracleTypes.UniswapTwapPriceOracleV2,
    ],
};
const oracleConfig = (deployments, artifacts, availableOracles) => {
    const asMap = new Map(availableOracles.map((o) => [o, { artifact: artifacts[o], address: deployments[o].address }]));
    return Object.fromEntries(asMap);
};
exports.oracleConfig = oracleConfig;
const irmConfig = (deployments, artifacts) => {
    return {
        JumpRateModel: {
            artifact: artifacts.JumpRateModel,
            address: deployments.JumpRateModel.address,
        },
        WhitePaperInterestRateModel: {
            artifact: artifacts.WhitePaperInterestRateModel,
            address: deployments.WhitePaperInterestRateModel.address,
        },
    };
};
exports.irmConfig = irmConfig;
