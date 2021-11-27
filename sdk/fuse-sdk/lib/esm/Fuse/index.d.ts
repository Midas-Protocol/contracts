import { constants, Contract } from "ethers";
import { JsonRpcProvider, Web3Provider } from "@ethersproject/providers";
declare type MinifiedContracts = {
    [key: string]: {
        abi?: any;
        bin?: any;
    };
};
declare type interestRateModelParams = {
    baseRatePerYear?: string;
    multiplierPerYear?: string;
    jumpMultiplierPerYear?: string;
    kink?: string;
};
declare type interestRateModelConf = {
    interestRateModel?: any;
    interestRateModelParams?: interestRateModelParams;
};
export declare type contractConfig = {
    COMPOUND_CONTRACT_ADDRESSES: {
        Comptroller: string;
        CErc20Delegate: string;
        CEther20Delegate: string;
        RewardsDistributorDelegate?: string;
        InitializableClones: string;
    };
    FUSE_CONTRACT_ADDRESSES: {
        FusePoolDirectory: string;
        FuseSafeLiquidator: string;
        FuseFeeDistributor: string;
        FusePoolLens: string;
        MasterPriceOracleImplementation: string;
        FusePoolLensSecondary: string;
    };
    PUBLIC_PRICE_ORACLE_CONTRACT_ADDRESSES: {
        PreferredPriceOracle?: string;
        ChainlinkPriceOracle?: string;
        ChainlinkPriceOracleV2?: string;
        UniswapView?: string;
        Keep3rPriceOracle_Uniswap?: string;
        Keep3rPriceOracle_SushiSwap?: string;
        Keep3rV2PriceOracle_Uniswap?: string;
        UniswapTwapPriceOracle_Uniswap?: string;
        UniswapTwapPriceOracle_RootContract?: string;
        UniswapTwapPriceOracleV2_RootContract?: string;
        UniswapTwapPriceOracle_SushiSwap?: string;
        UniswapLpTokenPriceOracle?: string;
        RecursivePriceOracle?: string;
        YVaultV1PriceOracle?: string;
        YVaultV2PriceOracle?: string;
        AlphaHomoraV1PriceOracle?: string;
        AlphaHomoraV2PriceOracle?: string;
        SynthetixPriceOracle?: string;
        BalancerLpTokenPriceOracle?: string;
        MasterPriceOracle?: string;
        CurveLpTokenPriceOracle?: string;
        CurveLiquidityGaugeV2PriceOracle?: string;
    };
    PRICE_ORACLE_RUNTIME_BYTECODE_HASHES: {
        ChainlinkPriceOracle?: string;
        ChainlinkPriceOracleV2?: string;
        UniswapTwapPriceOracle_Uniswap?: string;
        UniswapTwapPriceOracle_SushiSwap?: string;
        UniswapV3TwapPriceOracle_Uniswap_3000?: string;
        UniswapV3TwapPriceOracleV2_Uniswap_10000_USDC?: string;
        YVaultV1PriceOracle?: string;
        YVaultV2PriceOracle?: string;
        MasterPriceOracle?: string;
        CurveLpTokenPriceOracle?: string;
        CurveLiquidityGaugeV2PriceOracle?: string;
        FixedEthPriceOracle?: string;
        FixedEurPriceOracle?: string;
        WSTEthPriceOracle?: string;
        FixedTokenPriceOracle_OHM?: string;
        UniswapTwapPriceOracleV2_SushiSwap_DAI?: string;
        SushiBarPriceOracle?: string;
        UniswapV2_PairInit: string;
    };
    PUBLIC_INTEREST_RATE_MODEL_CONTRACT_ADDRESSES: {
        WhitePaperInterestRateModel_Compound_ETH?: string;
        WhitePaperInterestRateModel_Compound_WBTC?: string;
        JumpRateModel_Compound_Stables?: string;
        JumpRateModel_Compound_UNI?: string;
        JumpRateModel_Cream_Stables_Majors?: string;
        JumpRateModel_Cream_Gov_Seeds?: string;
        JumpRateModel_Cream_SLP?: string;
        JumpRateModel_ALCX?: string;
        JumpRateModel_Fei_FEI?: string;
        JumpRateModel_Fei_TRIBE?: string;
        JumpRateModel_Fei_ETH?: string;
        JumpRateModel_Fei_DAI?: string;
        JumpRateModel_Olympus_Majors?: string;
    };
    FACTORY: {
        UniswapV2_Factory: string;
        Sushiswap_Factory?: string;
        UniswapV3_Factory?: string;
        UniswapV3TwapPriceOracleV2_Factory: string;
        UniswapTwapPriceOracleV2_Factory: string;
    };
    TOKEN_ADDRESS: {
        USDC: string;
        W_TOKEN: string;
        DAI_POT: string;
        DAI_JUG: string;
    };
};
export default class Fuse {
    provider: JsonRpcProvider;
    constants: typeof constants;
    contracts: {
        [key: string]: Contract;
    };
    contractConfig: contractConfig;
    compoundContractsMini: MinifiedContracts;
    openOracleContracts: MinifiedContracts;
    oracleContracts: MinifiedContracts;
    getEthUsdPriceBN: any;
    identifyPriceOracle: any;
    deployPool: any;
    deployPriceOracle: any;
    deployComptroller: any;
    deployAsset: any;
    deployInterestRateModel: any;
    deployCToken: any;
    deployCEther: any;
    deployCErc20: any;
    identifyInterestRateModel: any;
    getInterestRateModel: any;
    checkForCErc20PriceFeed: any;
    getPriceOracle: any;
    deployRewardsDistributor: any;
    checkCardinality: any;
    primeUniswapV3Oracle: any;
    identifyInterestRateModelName: any;
    static ORACLES: string[];
    static COMPTROLLER_ERROR_CODES: string[];
    static CTOKEN_ERROR_CODES: string[];
    static JumpRateModelConf: interestRateModelConf;
    constructor(web3Provider: JsonRpcProvider | Web3Provider, contractConfig: contractConfig);
}
export {};
