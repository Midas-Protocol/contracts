import { deployments, network } from "hardhat";
import { use } from "chai";
import { solidity } from "ethereum-waffle";
// @ts-ignore
import Fuse, { cERC20Conf } from "midas-sdk";

use(solidity);

export const setUpTest = deployments.createFixture(async ({ deployments, getNamedAccounts, ethers }) => {
  console.log(network);
  await deployments.fixture(); // ensure you start from a fresh deployments
  const { deployer, alice, bob } = await getNamedAccounts();

  const FuseFeeDistributor = await ethers.getContract("FuseFeeDistributor", deployer);
  console.log("FuseFeeDistributor: ", FuseFeeDistributor.address);

  const FusePoolDirectory = await ethers.getContract("FusePoolDirectory", deployer);
  const Comptroller = await ethers.getContract("Comptroller", deployer);

  console.log(`Deployed Addresses:\n 
        - Comptroller: ${Comptroller.address}\n 
        - FusePoolDirectory: ${FusePoolDirectory.address}\n
        - FuseFeeDistributor: ${FuseFeeDistributor.address}\n`);

  const accts = [deployer, alice, bob];
  const isWhitelisted = await Promise.all(accts.map(async (d) => await FusePoolDirectory.deployerWhitelist(d)));
  console.log(
    "Whitelisted addresses: ",
    isWhitelisted.map((v, i) => `${accts[i]}: ${v}`)
  );
});
