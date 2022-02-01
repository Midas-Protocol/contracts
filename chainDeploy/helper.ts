export enum ChainlinkFeedBaseCurrency {
  ETH,
  USD,
}

export type ChainDeployConfig = {
  wtoken: string;
  nativeTokenUsdChainlinkFeed?: string;
};
