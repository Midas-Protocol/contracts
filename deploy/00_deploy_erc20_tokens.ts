import { utils } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer, alice, bob } = await getNamedAccounts();

  let dep = await deployments.deterministic("TRIBEToken", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [utils.parseEther("1250000000"), deployer],
    log: true,
  });
  const tribe = await dep.deploy();
  console.log("TRIBEToken: ", tribe.address);
  const tribeToken = await ethers.getContractAt("TRIBEToken", tribe.address, deployer);
  let tx = await tribeToken.transfer(alice, utils.parseEther("100000"), { from: deployer });
  await tx.wait();

  tx = await tribeToken.transfer(bob, utils.parseEther("100000"), { from: deployer });
  await tx.wait();

  dep = await deployments.deterministic("TOUCHToken", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [utils.parseEther("2250000000"), deployer],
    log: true,
  });
  const touch = await dep.deploy();
  const touchToken = await ethers.getContractAt("TOUCHToken", touch.address, deployer);
  tx = await touchToken.transfer(alice, utils.parseEther("100000"), { from: deployer });
  await tx.wait();

  tx = await touchToken.transfer(bob, utils.parseEther("100000"), { from: deployer });
  await tx.wait();
};

func.tags = ["Tokens"];
export default func;
