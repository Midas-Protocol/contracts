import { task } from "hardhat/config";
import { Comptroller, FusePoolDirectory } from "../typechain";
import { Fuse } from "../lib/esm/src";

task("fixtures", "Deploys demo fixture pools").setAction(async (_, hre) => {
  if (hre.network.name != "localhost") {
    console.log(`This task is build for localhost use only.\nContext: ${hre.network.name}`);
    return;
  }
  const { ethers } = hre;
  const { utils } = ethers;

  const { alice } = await ethers.getNamedSigners();

  const cpoFactory = await ethers.getContractFactory("MockPriceOracle", alice);
  const cpo = await cpoFactory.deploy([10]);

  const fpdWithSigner = await ethers.getContract<FusePoolDirectory>("FusePoolDirectory", alice);
  const implementationComptroller = await ethers.getContract<Comptroller>("Comptroller");

  //// DEPLOY POOL
  const POOL_NAME = "Fixture Pool 01";
  const bigCloseFactor = utils.parseEther((50 / 100).toString());
  const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());
  const deployPoolTx = await fpdWithSigner.deployPool(
    POOL_NAME,
    implementationComptroller.address,
    true,
    bigCloseFactor,
    bigLiquidationIncentive,
    cpo.address
  );
  await deployPoolTx.wait();
  console.log("Deployed pool");

  const pools = await fpdWithSigner.getPoolsByAccount(alice.address);
  const pool = pools[1].at(-1);
  console.log({ pools, pool });

  const sdk = new Fuse(ethers.provider, "1337");

  const allPools = await sdk.contracts.FusePoolDirectory.callStatic.getAllPools();
  const { comptroller, name: _unfiliteredName } = await allPools.filter((p) => p.creator === alice.address).at(-1);
});
