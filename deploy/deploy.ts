import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Hardhat task defining the contract deployments for nxtp
 *
 * @param hre Hardhat environment to deploy to
 */
const func: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
): Promise<void> => {
  let deployer: string;
  ({ deployer } = await hre.getNamedAccounts());
  console.log("deployer: ", deployer);

  await hre.deployments.deploy("FusePoolDirectory", {
    from: deployer,
    args: [],
    log: true,
  });
};
export default func;
