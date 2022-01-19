import { utils } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer } = await getNamedAccounts();

  let dep = await deployments.deterministic("TRIBEToken", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [utils.parseEther("1250000000")],
    log: true,
  });
  const rgt = await dep.deploy();
  console.log("RGT: ", rgt.address);

  dep = await deployments.deterministic("TOUCHToken", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [utils.parseEther("2250000000")],
    log: true,
  });
  const aave = await dep.deploy();
  console.log("AAVE: ", aave.address);
};

func.tags = ["Tokens"];
export default func;
