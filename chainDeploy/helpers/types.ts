import { HardhatRuntimeEnvironment, RunTaskFunction } from "hardhat/types";
import { BigNumber } from "ethers";

export enum ChainlinkFeedBaseCurrency {
  ETH,
  USD,
}

export type TokenPair = {
  token: string;
  baseToken: string;
};

export type ChainDeployConfig = {
  uniswap: {
    uniswapV2RouterAddress: string;
    uniswapV2FactoryAddress: string;
    uniswapOracleInitialDeployTokens: Array<TokenPair>;
    pairInitHashCode?: string;
    hardcoded: { name: string; symbol: string; address: string }[];
    uniswapData: { lpName: string; lpSymbol: string; lpDisplayName: string }[];
    uniswapOracleLpTokens?: Array<string>;
  };
  wtoken: string;
  nativeTokenUsdChainlinkFeed?: string;
  nativeTokenName: string;
  nativeTokenSymbol: string;
  stableToken?: string;
  wBTCToken?: string;
  blocksPerYear: number;
};

export type Asset = {
  symbol: string;
  underlying: string;
  name: string;
  decimals: number;
  simplePriceOracleAssetPrice?: BigNumber;
};

export type ChainlinkAsset = {
  symbol: string;
  aggregator: string;
  feedBaseCurrency: ChainlinkFeedBaseCurrency;
};

export type CurvePoolConfig = {
  lpToken: string;
  pool: string;
  underlyings: string[];
};

export type ChainDeployFnParams = {
  ethers: HardhatRuntimeEnvironment["ethers"];
  getNamedAccounts: HardhatRuntimeEnvironment["getNamedAccounts"];
  deployments: HardhatRuntimeEnvironment["deployments"];
  run: RunTaskFunction;
};

export type LiquidatorDeployFnParams = ChainDeployFnParams & {
  deployConfig: ChainDeployConfig;
};

export type IrmDeployFnParams = ChainDeployFnParams & {
  deployConfig: ChainDeployConfig;
};

export type ChainlinkDeployFnParams = ChainDeployFnParams & {
  assets: Asset[];
  chainlinkAssets: ChainlinkAsset[];
  deployConfig: ChainDeployConfig;
};

export type UniswapDeployFnParams = ChainDeployFnParams & {
  deployConfig: ChainDeployConfig;
};

export type CurveLpFnParams = ChainDeployFnParams & {
  deployConfig: ChainDeployConfig;
  curvePools: CurvePoolConfig[];
};
