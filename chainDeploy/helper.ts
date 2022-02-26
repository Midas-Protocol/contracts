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
  blocksPerYear: BigNumber;
};
