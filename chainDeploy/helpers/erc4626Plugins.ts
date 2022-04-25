import { constants, providers } from "ethers";
import { FuseFlywheelDeployFnParams } from "..";
import { SALT } from "../../deploy/deploy";
import { ChainlinkPriceOracleV2, FuseFlywheelCore } from "../../typechain";
import { Asset, ChainlinkDeployFnParams, ChainlinkFeedBaseCurrency } from "./types";

export const deployFlywheelWithDynamicRewards = async ({
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
}: FuseFlywheelDeployFnParams): Promise<any> => {
  const { deployer } = await getNamedAccounts();

  deployConfig.dynamicFlywheels.forEach(async (config) => {
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

    await flywheelCore.setFlywheelRewards(fdr.address);
  });
};

export const deployERC4626Plugin = async ({
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
}: FuseFlywheelDeployFnParams): Promise<any> => {
  const { deployer } = await getNamedAccounts();

  deployConfig.plugins?.forEach(async (pluginConfig, i) => {
    let dep = await deployments.deterministic(pluginConfig.strategy, {
      from: deployer,
      salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
      args: [pluginConfig.underlying, pluginConfig.name, pluginConfig.symbol, ...pluginConfig.otherParams],
      log: true,
    });
    const erc4626 = await dep.deploy();
    if (erc4626.transactionHash) await ethers.provider.waitForTransaction(erc4626.transactionHash);
    console.log(`${pluginConfig.strategy}-${i}: `, erc4626.address);
  });
};

// 1. Deploy Flywheel
// 2. Deploy Plugin
// 3. Deploy Market (CErc20PluginRewardsDelegate) <-- Takes Flywheel + Plugin

// AutofarmERC4626 1 == Address1
// AutofarmERC4626 2 == Address2
// AutofarmERC4626 3 == Address3
// AutofarmERC4626 4 == Address4
