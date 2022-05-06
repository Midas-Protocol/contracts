import func from "./deploy";
import { DeployFunction } from "hardhat-deploy/types";
import { ChainDeployConfig, chainDeployConfig } from "../chainDeploy";
import {ethers} from "hardhat";

// use with mainnet forking to simulate the prod deployment
const simulateDeploy: DeployFunction = async (hre): Promise<void> => {
  const chainId = await hre.getChainId();
  console.log("chainId: ", chainId);
  if (!chainDeployConfig[chainId]) {
    throw new Error(`Config invalid for ${chainId}`);
  }
  const { config: chainDeployParams }: { config: ChainDeployConfig } =
      chainDeployConfig[chainId];
  console.log("whale: ", chainDeployParams.wtoken);

  const { deployer } = await hre.getNamedAccounts();
  await ethers.provider.send("hardhat_impersonateAccount", [chainDeployParams.wtoken]);
  const signer = hre.ethers.provider.getSigner(chainDeployParams.wtoken);
  await signer.sendTransaction({ to: deployer, value: hre.ethers.utils.parseEther("10") });
  await func(hre);
};
simulateDeploy.tags = ["simulate", "fork", "local"];

export default simulateDeploy;
