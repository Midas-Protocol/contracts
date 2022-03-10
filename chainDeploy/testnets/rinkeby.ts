import { ChainDeployConfig } from "../helpers";

export const deployConfig: ChainDeployConfig = {
  wtoken: "0xc778417e063141139fce010982780140aa0cd5ab", // WETH
  nativeTokenName: "Rinkeby (Testnet)",
  nativeTokenSymbol: "ETH",
  blocksPerYear: 4 * 24 * 365 * 60, // 15 second blocks, 4 blocks per minute
  wBTCToken: "0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735", // DAI
  uniswap: {
    hardcoded: [],
    uniswapData: [],
    pairInitHashCode: "0x",
    uniswapV2RouterAddress: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    uniswapV2FactoryAddress: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
    uniswapOracleInitialDeployTokens: [],
  },
};

export const deploy = async ({ getNamedAccounts, deployments, ethers }): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  console.log("deployer: ", deployer);
};
