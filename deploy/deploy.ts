import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Hardhat task defining the contract deployments for nxtp
 *
 * @param hre Hardhat environment to deploy to
 */
const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { bob, alice, deployer } = await getNamedAccounts();
  console.log("deployer: ", deployer);

  let dep = await deployments.deterministic("FusePoolDirectory", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fpd = await dep.deploy();
  console.log("FusePoolDirectory: ", fpd.address);
  const fusePoolDirectory = await ethers.getContract("FusePoolDirectory", deployer);
  let tx = await fusePoolDirectory.initialize(true, [deployer, alice, bob]);
  await tx.wait();

  dep = await deployments.deterministic("FuseSafeLiquidator", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fsl = await dep.deploy();
  console.log("FuseSafeLiquidator: ", fsl.address);

  dep = await deployments.deterministic("FuseFeeDistributor", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const ffd = await dep.deploy();
  console.log("FuseFeeDistributor: ", ffd.address);
  const fuseFeeDistributor = await ethers.getContract("FuseFeeDistributor", deployer);
  tx = await fuseFeeDistributor.initialize(ethers.utils.parseEther("0.1"));
  await fuseFeeDistributor._setPoolLimits(
    ethers.utils.parseEther("1"),
    ethers.constants.MaxUint256,
    ethers.constants.MaxUint256
  );

  dep = await deployments.deterministic("FusePoolLens", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fpl = await dep.deploy();
  console.log("FusePoolLens: ", fpl.address);
  const fusePoolLens = await ethers.getContract("FusePoolLens", deployer);
  tx = await fusePoolLens.initialize(fusePoolDirectory.address);

  dep = await deployments.deterministic("JumpRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [
      "20000000000000000", // baseRatePerYear
      "200000000000000000", // multiplierPerYear
      "2000000000000000000", //jumpMultiplierPerYear
      "900000000000000000", // kink
    ],
    log: true,
  });
  const jrm = await dep.deploy();
  console.log("JumpRateModel: ", jrm.address);
};
export default func;
