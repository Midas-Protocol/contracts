import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Hardhat task defining the contract deployments for nxtp
 *
 * @param hre Hardhat environment to deploy to
 */
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment): Promise<void> => {
  const { bob, alice, deployer } = await hre.getNamedAccounts();
  console.log("deployer: ", deployer);

  await hre.deployments.deploy("FusePoolDirectory", {
    from: deployer,
    args: [],
    log: true,
    proxy: true,
  });
  await hre.deployments.deploy("FuseSafeLiquidator", {
    from: deployer,
    args: [],
    log: true,
    proxy: true,
  });
  await hre.deployments.deploy("FuseFeeDistributor", {
    from: deployer,
    args: [hre.ethers.BigNumber.from(10e16).toString()],
    log: true,
    proxy: true,
  });

  const fusePoolDirectory = await hre.ethers.getContract("FusePoolDirectory", deployer);
  const fuseFeeDistributor = await hre.ethers.getContract("FuseFeeDistributor", deployer);

  await fuseFeeDistributor._setPoolLimits(
    hre.ethers.BigNumber.from(1e18),
    hre.ethers.BigNumber.from(2).pow(hre.ethers.BigNumber.from(256)).sub(1),
    hre.ethers.BigNumber.from(2).pow(hre.ethers.BigNumber.from(256)).sub(1)
  );

  await hre.deployments.deploy("FusePoolLens", {
    from: deployer,
    args: [fusePoolDirectory.address],
    log: true,
    proxy: true,
  });

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
