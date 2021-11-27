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
  const { bob, alice, deployer } = await hre.getNamedAccounts();
  console.log("deployer: ", deployer);

  await hre.deployments.deploy("FusePoolDirectory", {
    from: deployer,
    args: [],
    log: true,
  });
  await hre.deployments.deploy("FuseFeeDistributor", {
    from: deployer,
    args: [],
    log: true,
  });
  await hre.deployments.deploy("Comptroller", {
    from: deployer,
    args: [],
    log: true,
  });
  const fusePoolDirectory = await hre.ethers.getContract(
    "FusePoolDirectory",
    deployer
  );
  const tx = await fusePoolDirectory.initialize(true, [deployer, alice, bob]);
  await tx.wait();

  await hre.deployments.deploy("JumpRateModel", {
    from: deployer,
    args: [
      "20000000000000000", // baseRatePerYear
      "200000000000000000", // multiplierPerYear
      "2000000000000000000", //jumpMultiplierPerYear
      "900000000000000000", // kink
    ],
    log: true,
  });
};
export default func;
