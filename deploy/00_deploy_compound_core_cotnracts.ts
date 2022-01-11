import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  let dep = await deployments.deterministic("Comptroller", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });

  const comp = await dep.deploy();
  console.log("Comptroller: ", comp.address);

  dep = await deployments.deterministic("CErc20Delegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const erc20Del = await dep.deploy();
  console.log("CErc20Delegate: ", erc20Del.address);

  dep = await deployments.deterministic("CEtherDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const ethDel = await dep.deploy();
  console.log("CEtherDelegate: ", ethDel.address);

  dep = await deployments.deterministic("RewardsDistributorDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });

  const rewards = await dep.deploy();
  // const rewardsDistributorDelegate = await ethers.getContract("RewardsDistributorDelegate", deployer);
  // await rewardsDistributorDelegate.initialize(constants.AddressZero);
  console.log("RewardsDistributorDelegate: ", rewards.address);
};

func.tags = ["Compound"];
export default func;
