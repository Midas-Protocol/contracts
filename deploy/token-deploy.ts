import { constants, providers } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";

import { ChainDeployConfig, chainDeployConfig } from "../chainDeploy";

import { SALT } from "./deploy";
import {ethers} from "hardhat";

const func: DeployFunction = async ({ run, ethers, getNamedAccounts, deployments, getChainId }): Promise<void> => {
    const chainId = await getChainId();
    console.log("chainId: ", chainId);
    const { deployer, alice } = await getNamedAccounts();
    console.log("deployer: ", deployer);

    if (!chainDeployConfig[chainId]) {
        throw new Error(`Config invalid for ${chainId}`);
    }
    const chainDeployParams: ChainDeployConfig = chainDeployConfig[chainId].config;
    console.log("chainDeployParams: ", chainDeployParams);

    const tribeDAO = "0xdEAd00000000000000000000000000000000cAFE";
    let tx: providers.TransactionResponse;
    const initSupply = ethers.utils.parseUnits("100000000", 18);
    console.log(`init supply ${initSupply}`)
    let dep = await deployments.deterministic("TOUCHToken", {
        from: deployer,
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
        args: [initSupply, alice],
        log: true,
    });
    const touch = await dep.deploy();
    console.log("TOUCHToken: ", touch.address);
    const touchToken = await ethers.getContractAt("TOUCHToken", touch.address, alice);
    tx = await touchToken.transfer(tribeDAO, ethers.utils.parseEther("25000000"));
    await tx.wait();
};

func.tags = ["token"];

export default func;
