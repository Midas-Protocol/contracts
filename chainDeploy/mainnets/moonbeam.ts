import { ChainDeployConfig, deployUniswapOracle } from "../helpers";
import { ethers } from "ethers";
import { ChainDeployFnParams, ChainlinkAsset } from "../helpers/types";
import { deployUniswapLpOracle } from "../oracles/uniswapLp";
import { SALT } from "../../deploy/deploy";

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
    uniswapOracleInitialDeployTokens: [
      {
        token: "0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b", // USDC
        baseToken: "0xAcc15dC74880C9944775448304B263D191c6077F", // GLMR
      },
      {
        token: "0xcd3B51D98478D53F4515A306bE565c6EebeF1D58", // GLINT
        baseToken: "0xAcc15dC74880C9944775448304B263D191c6077F", // GLMR
      },
    ],
    uniswapOracleLpTokens: [
      "0xb929914B89584b4081C7966AC6287636F7EfD053", // GLMR-USDC
      "0x99588867e817023162F4d4829995299054a5fC57", // GLMR-GLINT
    ],
  },
};

const chainlinkAssets: ChainlinkAsset[] = [];

export const deploy = async ({ run, ethers, getNamedAccounts, deployments }: ChainDeployFnParams): Promise<void> => {
  console.log("no chain specific deployments to run");
  const { deployer } = await getNamedAccounts();

  // const masterPriceOracle = ethers.getContractFactory("MasterPriceOracle", deployer);
  // const mpo = (await masterPriceOracle).deploy();

  //// Uniswap Oracle
  await deployUniswapOracle({ run, ethers, getNamedAccounts, deployments, deployConfig });
  ////

  //// Uniswap Lp Oracle
  await deployUniswapLpOracle({ run, ethers, getNamedAccounts, deployments, deployConfig });

  //// Uniswap Lp token liquidator

  let dep = await deployments.deterministic("UniswapLpTokenLiquidator", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const uniswapLpTokenLiquidator = await dep.deploy();
  if (uniswapLpTokenLiquidator.transactionHash) {
    await ethers.provider.waitForTransaction(uniswapLpTokenLiquidator.transactionHash);
  }
  console.log("UniswapLpTokenLiquidator: ", uniswapLpTokenLiquidator.address);
};
