import { Artifacts, ChainDeployment } from "./Fuse/types";
export declare enum SupportedChains {
    bsc = 56,
    chapel = 97,
    ganache = 1337,
    aurora = 1313161555,
    harmony = 1666600000
}
export declare const chainSpecificAddresses: {
    1337: {
        DAI_POT: string;
        DAI_JUG: string;
        USDC: string;
        W_TOKEN: string;
        W_TOKEN_USD_CHAINLINK_PRICE_FEED: string;
    };
    97: {
        DAI_POT: string;
        DAI_JUG: string;
        USDC: string;
        W_TOKEN: string;
        W_TOKEN_USD_CHAINLINK_PRICE_FEED: string;
    };
    56: {
        DAI_POT: string;
        DAI_JUG: string;
        USDC: string;
        W_TOKEN: string;
        W_TOKEN_USD_CHAINLINK_PRICE_FEED: string;
    };
};
export declare const chainOracles: {
    1337: ("SimplePriceOracle" | "MasterPriceOracle")[];
    97: ("ChainlinkPriceOracleV2" | "MasterPriceOracle" | "UniswapTwapPriceOracleV2")[];
};
export declare const oracleConfig: (deployments: ChainDeployment, artifacts: Artifacts, availableOracles: Array<string>) => {
    [k: string]: {
        artifact: import("./Fuse/types").Artifact;
        address: string;
    };
};
export declare const irmConfig: (deployments: ChainDeployment, artifacts: Artifacts) => {
    JumpRateModel: {
        artifact: import("./Fuse/types").Artifact;
        address: string;
    };
    WhitePaperInterestRateModel: {
        artifact: import("./Fuse/types").Artifact;
        address: string;
    };
};
