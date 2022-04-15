import { ChainDeployConfig, deployUniswapOracle } from "../helpers";
import { ethers } from "ethers";
import { ChainDeployFnParams, ChainlinkAsset } from "../helpers/types";

export const deployConfig: ChainDeployConfig = {
  wtoken: "0xAcc15dC74880C9944775448304B263D191c6077F",
  nativeTokenName: "Moonbeam",
  nativeTokenSymbol: "GLMR",
  blocksPerYear: 5 * 24 * 365 * 60, // 12 second blocks, 5 blocks per minute
  uniswap: {
    hardcoded: [],
    uniswapData: [],
    pairInitHashCode: ethers.utils.hexlify("0xd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66"),
    uniswapV2RouterAddress: "0xAA30eF758139ae4a7f798112902Bf6d65612045f",
    uniswapV2FactoryAddress: "0x049581aEB6Fe262727f290165C29BDAB065a1B68",
    uniswapOracleInitialDeployTokens: [],
  },
};

const chainlinkAssets: ChainlinkAsset[] = [];

export const deploy = async ({ run, ethers, getNamedAccounts, deployments }: ChainDeployFnParams): Promise<void> => {
  console.log("no chain specific deployments to run");
  //// Uniswap Oracle
  await deployUniswapOracle({ run, ethers, getNamedAccounts, deployments, deployConfig });
  ////
};
