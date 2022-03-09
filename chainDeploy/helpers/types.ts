export enum ChainlinkFeedBaseCurrency {
  ETH,
  USD,
}

export type ChainDeployConfig = {
  uniswap: {
    uniswapV2RouterAddress: string;
    uniswapV2FactoryAddress: string;
    uniswapOracleInitialDeployTokens: Array<string>;
    pairInitHashCode?: string;
    hardcoded: { name: string; symbol: string; address: string }[];
    uniswapData: { lpName: string; lpSymbol: string; lpDisplayName: string }[];
  };
  wtoken: string;
  nativeTokenUsdChainlinkFeed?: string;
  nativeTokenName: string;
  nativeTokenSymbol: string;
  stableToken?: string;
  wBTCToken?: string;
  blocksPerYear: number;
};
