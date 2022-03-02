import { ChainDeployConfig } from "../helpers";

export const deployConfig: ChainDeployConfig = {
  wtoken: "0xA30404AFB4c43D25542687BCF4367F59cc77b5d2",
  nativeTokenName: "Evmos (Testnet)",
  nativeTokenSymbol: "TEVMOS",
  blocksPerYear: 12 * 24 * 365 * 60, // 5 second blocks, 12 blocks per minute
  hardcoded: [],
  uniswapData: [],
  pairInitHashCode: "0x",
};

export const deploy = async ({ getNamedAccounts }): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  console.log("deployer: ", deployer);
};
