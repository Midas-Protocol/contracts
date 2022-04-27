import { constants } from "ethers";
import { Erc4626PluginDeployFnParams, FuseFlywheelDeployFnParams } from "..";
import { SALT } from "../../deploy/deploy";
import { FuseFlywheelCore } from "../../typechain/FuseFlywheelCore";

export const deployFlywheelWithDynamicRewards = async ({
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
}: FuseFlywheelDeployFnParams): Promise<Array<string>> => {
  const { deployer } = await getNamedAccounts();

  const dynamicFlywheels = [];

  for (const config of deployConfig.dynamicFlywheels) {
    if (config) {
      console.log(`Deploying FuseFlywheelCore & FuseFlywheelDynamicRewards for ${config.rewardToken} reward token`);
      //// FuseFlyhweelCore with Dynamic Rewards
      let dep = await deployments.deterministic("FuseFlywheelCore", {
        from: deployer,
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
        args: [config.rewardToken, constants.AddressZero, constants.AddressZero, deployer, constants.AddressZero],
        log: true,
      });
      const fwc = await dep.deploy();
      if (fwc.transactionHash) await ethers.provider.waitForTransaction(fwc.transactionHash);
      console.log("FuseFlywheelCore: ", fwc.address);

      dep = await deployments.deterministic("FuseFlywheelDynamicRewards", {
        from: deployer,
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
        args: [fwc.address, config.cycleLength],
        log: true,
      });
      const fdr = await dep.deploy();
      if (fdr.transactionHash) await ethers.provider.waitForTransaction(fdr.transactionHash);
      console.log("FuseFlywheelDynamicRewards: ", fdr.address);

      const flywheelCore = (await ethers.getContractAt("FuseFlywheelCore", fwc.address, deployer)) as FuseFlywheelCore;
      const tx = await flywheelCore.setFlywheelRewards(fdr.address, { from: deployer });
      await tx.wait();
      dynamicFlywheels.push(fdr.address);
    } else {
      dynamicFlywheels.push(null);
    }
  }
  return dynamicFlywheels;
};

export const deployERC4626Plugin = async ({
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
  dynamicFlywheels,
}: Erc4626PluginDeployFnParams): Promise<void> => {
  const { deployer } = await getNamedAccounts();

  for (const pluginConfig of deployConfig.plugins) {
    if (pluginConfig) {
      const hasFlywheel = pluginConfig.flywheelIndex || pluginConfig.flywheelAddress;
      let args = hasFlywheel
        ? [
            pluginConfig.underlying,
            pluginConfig.flywheelIndex ? dynamicFlywheels[pluginConfig.flywheelIndex] : pluginConfig.flywheelAddress,
            ...pluginConfig.otherParams,
          ]
        : [pluginConfig.underlying, pluginConfig.otherParams];

      const i = deployConfig.plugins.indexOf(pluginConfig);
      let dep = await deployments.deterministic(pluginConfig.strategy, {
        from: deployer,
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
        args: args,
        log: true,
      });
      const erc4626 = await dep.deploy();
      if (erc4626.transactionHash) await ethers.provider.waitForTransaction(erc4626.transactionHash);
      console.log(`${pluginConfig.strategy}-${i}: `, erc4626.address);
    }
  }
};

// 1. Deploy Flywheel
// 2. Deploy Plugin
// 3. Deploy Market (CErc20PluginRewardsDelegate) <-- Takes Flywheel + Plugin

// AutofarmERC4626 1 == Address1
// AutofarmERC4626 2 == Address2
// AutofarmERC4626 3 == Address3
// AutofarmERC4626 4 == Address4
