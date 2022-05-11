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
  const fundingValue = hre.ethers.utils.parseEther("100");
  let whale = chainDeployParams.wtoken;
  const balanceOfWToken = await ethers.provider.getBalance(whale);
  if (balanceOfWToken < fundingValue) {
    whale = (await hre.getNamedAccounts())["alice"];
  }
  console.log("whale: ", whale);

  const { deployer } = await hre.getNamedAccounts();
  await ethers.provider.send("hardhat_impersonateAccount", [whale]);
  const signer = hre.ethers.provider.getSigner(whale);
  await signer.sendTransaction({ to: deployer, value: fundingValue });
  await func(hre);
};
simulateDeploy.tags = ["simulate", "fork", "local"];

export default simulateDeploy;
