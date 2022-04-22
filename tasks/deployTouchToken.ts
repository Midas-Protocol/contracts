import { task } from "hardhat/config";
import { providers } from "ethers";
import {ChainDeployConfig, chainDeployConfig} from "../chainDeploy";
import {SALT} from "../deploy/deploy";

export default task("deploy-touch-token", "Deploy the Midas TOUCH Token")
    .addParam("chainTouchSupply", "The TOUCH tokens supply in circulation for this chain")
    .addOptionalParam("tribeDaoAddress", "Address to which the TribeDAO tokens should be allocated")
    .setAction(async ({ chainTouchSupply: _chainTouchSupply, tribeDaoAddress: _tribeDaoAddress }, { getNamedAccounts, ethers, getChainId, deployments }) => {
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
        const initSupply = ethers.utils.parseUnits(_chainTouchSupply, 18);
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
    });