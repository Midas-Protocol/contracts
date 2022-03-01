import { ChainDeployConfig } from "./helpers";
import { BigNumber } from "ethers";

// see https://gov.near.org/t/evm-runtime-base-token/340/24
export const deployConfig1313161554: ChainDeployConfig = {
  wtoken: "0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB",
  nativeTokenName: "ETH",
  nativeTokenSymbol: "Ethereum",
  blocksPerYear: BigNumber.from((50 * 24 * 365 * 60).toString()),
  uniswapV2RouterAddress: "",
  stableToken: "",
  wBTCToken: "",
};
