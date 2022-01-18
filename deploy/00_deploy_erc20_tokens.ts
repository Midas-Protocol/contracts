import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer } = await getNamedAccounts();

  let dep = await deployments.deterministic("AAVEToken", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: ["Rari Governance Token", "RGT", 1250000000],
    log: true,
  });
  const rgt = await dep.deploy();
  console.log("RGT: ", rgt.address);

  dep = await deployments.deterministic("RGTToken", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: ["AAVE Token", "AAVE", 2250000000],
    log: true,
  });
  const aave = await dep.deploy();
  console.log("AAVE: ", aave.address);
};

func.tags = ["Tokens"];
export default func;
