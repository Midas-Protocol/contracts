import { createPool, deployAssets, getAssetsConf, getPoolIndex } from "../test/utils/pool";
import { task, types } from "hardhat/config";
import { Fuse, FusePoolData } from "../lib/esm/src";
import { addCollateral, borrowCollateral } from "../test/utils/collateral";

const logPoolData = async (poolAddress, creatorAddress, sdk) => {
  const poolIndex = await getPoolIndex(poolAddress, creatorAddress, sdk);
  const fusePoolData: FusePoolData = await sdk.fetchFusePoolData(poolIndex, poolAddress);
  const poolAssets = fusePoolData.assets.map((a) => a.underlyingSymbol).join(", ");
  console.log(`Pool with address ${poolAddress},  mame: ${fusePoolData.name}, assets ${poolAssets} created!`);
};

export default task("create-pools", "Create Testing Pools")
  .addParam("name", "Name of the pool to be created")
  .addOptionalParam("depositAmount", "Amount to deposit", 0, types.int)
  .addOptionalParam("depositSymbol", "Amount to deposit", "ETH")
  .addOptionalParam("borrowAmount", "Amount to deposit", 0, types.int)
  .addOptionalParam("borrowSymbol", "Amount to deposit", "ETH")
  .setAction(
    async (
      {
        name: _name,
        depositAmount: _depositAmount,
        depositSymbol: _depositSymbol,
        borrowAmount: _borrowAmount,
        borrowSymbol: _borrowSymbol,
      },
      { ethers }
    ) => {
      const sdk = new Fuse(ethers.provider, "1337");
      const { bob } = await ethers.getNamedSigners();
      const [poolAddress] = await createPool({ ethers, poolName: _name, signer: bob });
      const assets = await getAssetsConf(ethers, poolAddress);
      await deployAssets(ethers, assets.assets, bob);
      await logPoolData(poolAddress, bob.address, sdk);
      if (_depositAmount != 0) {
        await addCollateral(ethers, poolAddress, bob.address, _depositSymbol, _depositAmount.toString());
      }
      if (_borrowAmount != 0) {
        await borrowCollateral(ethers, poolAddress, bob.address, _borrowSymbol, _borrowAmount.toString());
      }
    }
  );
