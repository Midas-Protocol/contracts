import { ChainDeployConfig } from "../helpers";

export const deployConfig: ChainDeployConfig = {
  wtoken: "",
  nativeTokenName: "EMVOS",
  nativeTokenSymbol: "PHO",
  blocksPerYear: 8.6 * 24 * 365 * 60,
  stableToken: "",
  wBTCToken: "",
  uniswap: {
    hardcoded: [],
    uniswapData: [],
    pairInitHashCode: "0x",
    uniswapV2RouterAddress: "",
    uniswapV2FactoryAddress: "",
    uniswapOracleInitialDeployTokens: [],
  },
};
