import { Fuse, FusePoolData } from "../lib/esm/src";
import { createPool, deployAssets, getAssetsConf } from "../test/utils";
import hre, { ethers } from "hardhat";
import { getPoolIndex } from "../test/utils/pool";

const logPoolData = async (poolAddress, creatorAddress, sdk) => {
  const poolIndex = await getPoolIndex(poolAddress, creatorAddress, sdk);
  const fusePoolData: FusePoolData = await sdk.fetchFusePoolData(poolIndex, poolAddress);
  const poolAssets = fusePoolData.assets.map((a) => a.underlyingSymbol).join(", ");
  console.log(`Pool with address ${poolAddress},  mame: ${fusePoolData.name}, assets ${poolAssets} created!`);
};

async function main() {
  const sdk = new Fuse(hre.ethers.provider, "1337");
  const POOL_NAME = "test pool " + (Math.random() + 1).toString(36).substring(7);
  const { bob } = await ethers.getNamedSigners();
  const [poolAddress] = await createPool({ poolName: POOL_NAME, signer: bob });
  console.log(poolAddress);
  const assets = await getAssetsConf(poolAddress);
  await deployAssets(assets.assets, bob);
  await logPoolData(poolAddress, bob.address, sdk);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
