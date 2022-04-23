import { task, types } from "hardhat/config";
import { providers } from "ethers";
import { ChainDeployConfig, chainDeployConfig } from "../chainDeploy";
import {deployments} from "hardhat";

export default task("deploy-touch-vesting", "Deploy a vesting contract for the TOUCH token")
    .addParam("beneficiaryAddress", "Address which can claim the vested TOUCH tokens")
    .addParam("durationSeconds", "The total duration of the vesting, the cliff included, in seconds")
    .addParam("cliffSeconds", "The total duration of the cliff, in seconds")
    .addParam("clawbackAdminAddress", "The address of the admin that is able to revoke the vesting")
    .addOptionalParam("startTime", "The start time of the vesting, in seconds since 1970")
    .setAction(async ({
                          beneficiaryAddress: _beneficiaryAddress,
                          durationSeconds: _durationSeconds,
                          cliffSeconds: _cliffSeconds,
                          clawbackAdminAddress: _clawbackAdminAddress,
                          startTime: _startTime,
                      }, { getNamedAccounts, ethers, getChainId, deployments }) => {
        const chainId = await getChainId();
        console.log("chainId: ", chainId);
        const { deployer, alice } = await getNamedAccounts();
        console.log("deployer: ", deployer);

        if (!chainDeployConfig[chainId]) {
            throw new Error(`Config invalid for ${chainId}`);
        }
        const chainDeployParams: ChainDeployConfig = chainDeployConfig[chainId].config;
        console.log("chainDeployParams: ", chainDeployParams);

        const touchToken = await ethers.getContract("TOUCHToken", alice);
        console.log("TOUCHToken: ", touchToken.address);

        let deployedTimelock = await deployments.deterministic("LinearTokenTimelock", {
            from: deployer,
            args: [_beneficiaryAddress, _durationSeconds, _cliffSeconds, touchToken.address, _clawbackAdminAddress, _startTime],
            log: true,
            skipIfAlreadyDeployed: false,
        });

        console.log("timelock deployed to ", deployedTimelock.address);
    });