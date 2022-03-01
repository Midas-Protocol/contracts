import { BigNumber } from "ethers";

export enum ChainlinkFeedBaseCurrency {
  ETH,
  USD,
}

export type ChainDeployConfig = {
  wtoken: string;
  nativeTokenUsdChainlinkFeed?: string;
  nativeTokenName: string;
  nativeTokenSymbol: string;
  uniswapV2RouterAddress: string;
  stableToken: string;
  wBTCToken: string;
  blocksPerYear: BigNumber;
};
