import { BigNumber, Contract } from "ethers";
import { JsonRpcProvider, Web3Provider } from "@ethersproject/providers";
import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { Artifact, Artifacts, cERC20Conf, ChainDeployment, FusePoolData, InterestRateModel, InterestRateModelConf, InterestRateModelParams, OracleConf } from "./types";
import { SupportedChains } from "../network";
declare type OracleConfig = {
    [contractName: string]: {
        artifact: Artifact;
        address: string;
    };
};
declare type ChainSpecificAddresses = {
    [tokenName: string]: string;
};
export default class Fuse {
    provider: JsonRpcProvider | Web3Provider;
    contracts: {
        FusePoolDirectory: Contract;
        FusePoolLens: Contract;
        FusePoolLensSecondary: Contract;
        FuseSafeLiquidator: Contract;
        FuseFeeDistributor: Contract;
    };
    static SIMPLE_DEPLOY_ORACLES: string[];
    static COMPTROLLER_ERROR_CODES: string[];
    static CTOKEN_ERROR_CODES: string[];
    static JumpRateModelConf: InterestRateModelConf;
    availableOracles: Array<string>;
    chainId: SupportedChains;
    chainDeployment: ChainDeployment;
    oracles: OracleConfig;
    private readonly irms;
    chainSpecificAddresses: ChainSpecificAddresses;
    artifacts: Artifacts;
    constructor(web3Provider: JsonRpcProvider | Web3Provider, chainId: SupportedChains);
    getUsdPriceBN(coingeckoId?: string, asBigNumber?: boolean): Promise<number | BigNumber>;
    deployPool(poolName: string, enforceWhitelist: boolean, closeFactor: BigNumber, liquidationIncentive: BigNumber, priceOracle: string, // Contract address
    priceOracleConf: OracleConf, options: any, // We might need to add sender as argument. Getting address from options will colide with the override arguments in ethers contract method calls. It doesnt take address.
    whitelist: string[]): Promise<[string, string, string]>;
    private getOracleContractFactory;
    deployAsset(irmConf: InterestRateModelConf, cTokenConf: cERC20Conf, options: any): Promise<[string, string, string, TransactionReceipt]>;
    deployInterestRateModel(options: any, model?: string, conf?: InterestRateModelParams): Promise<string>;
    deployCToken(conf: cERC20Conf, options: any): Promise<[string, string, TransactionReceipt]>;
    deployCEther(conf: cERC20Conf, options: any, implementationAddress: string | null): Promise<[string, string, TransactionReceipt]>;
    deployCErc20(conf: cERC20Conf, options: any, implementationAddress: string | null): Promise<[string, string, TransactionReceipt]>;
    identifyPriceOracle(priceOracleAddress: string): Promise<string | null>;
    identifyInterestRateModel(interestRateModelAddress: string): Promise<InterestRateModel | null>;
    getInterestRateModel(assetAddress: string): Promise<any | undefined | null>;
    checkForCErc20PriceFeed(comptroller: Contract, conf: {
        underlying: string;
    }, options?: any): Promise<void>;
    getPriceOracle(oracleAddress: string): Promise<string | null>;
    deployRewardsDistributor(rewardToken: any, options: {
        from: any;
    }): Promise<Contract>;
    checkCardinality(uniswapV3Pool: string): Promise<boolean>;
    primeUniswapV3Oracle(uniswapV3Pool: any, options: any): Promise<void>;
    identifyInterestRateModelName: (irmAddress: string) => string | null;
    fetchFusePoolData: (poolId: string | undefined, address?: string | undefined, coingeckoId?: string | undefined) => Promise<FusePoolData | undefined>;
}
export {};
