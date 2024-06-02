import { task, types } from "hardhat/config";
import { providers, constants } from "ethers";
import {ChainDeployConfig, chainDeployConfig} from "../chainDeploy";

export default task("deploy-touch-token", "Deploy the Midas TOUCH Token")
    .addOptionalParam("chainTouchSupply", "The TOUCH tokens supply in circulation for this chain", "100000000", types.string)
    .addOptionalParam("tribeDaoAddress", "Address to which the TribeDAO tokens should be allocated", constants.AddressZero, types.string)
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

        let tx: providers.TransactionResponse;
        const initSupply = ethers.utils.parseUnits(_chainTouchSupply, 18);
        console.log(`initial supply ${initSupply}`)
        const touch = await deployments.deploy("TOUCHToken", {
            from: deployer,
            args: [alice, initSupply],
            log: true,
        });
        console.log("TOUCHToken: ", touch.address);
        const touchToken = await ethers.getContractAt("TOUCHToken", touch.address, alice);

        if (_tribeDaoAddress != constants.AddressZero) {
            console.log("transferring the TribeDAO allocation to ", _tribeDaoAddress);
            tx = await touchToken.transfer(_tribeDaoAddress, ethers.utils.parseEther("25000000"));
            const receipt = await tx.wait();
            console.log(`TribeDAO tokens transferred with tx ${receipt.transactionHash}`);
        }
    });