import { task, types } from "hardhat/config";
import { getPoolByName } from "../test/utils/pool";

const logPoolData = async (poolAddress, creatorAddress, sdk) => {
  const poolModule = await import("../test/utils/pool");
  const poolIndex = await poolModule.getPoolIndex(poolAddress, creatorAddress, sdk);
  const fusePoolData = await sdk.fetchFusePoolData(poolIndex, poolAddress);

  const poolAssets = fusePoolData.assets.map((a) => a.underlyingSymbol).join(", ");
  console.log(`Operating on pool with address ${poolAddress},  mame: ${fusePoolData.name}, assets ${poolAssets}`);
};

export default task("create-pools", "Create Testing Pools")
  .addParam("name", "Name of the pool to be created")
  .addOptionalParam("depositAmount", "Amount to deposit", 0, types.string)
  .addOptionalParam("depositSymbol", "Amount to deposit", "ETH")
  .addOptionalParam("borrowAmount", "Amount to deposit", 0, types.string)
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
      const poolModule = await import("../test/utils/pool");
      // @ts-ignore
      const sdkModule = await import("../lib/esm/src");
      const collateralModule = await import("../test/utils/collateral");
      const sdk = new sdkModule.Fuse(ethers.provider, "1337");
      const { bob } = await ethers.getNamedSigners();

      const existingPool = await getPoolByName(_name, bob.address, sdk);

      let poolAddress: string;
      if (existingPool !== null) {
        console.log(`Pool with name ${existingPool.name} exists already, will operate on it`);
        poolAddress = existingPool.comptroller;
      } else {
        [poolAddress] = await poolModule.createPool({ ethers, poolName: _name, signer: bob });
        const assets = await poolModule.getAssetsConf(ethers, poolAddress);
        await poolModule.deployAssets(ethers, assets.assets, bob);
      }

      await logPoolData(poolAddress, bob.address, sdk);
      if (_depositAmount != 0) {
        await collateralModule.addCollateral(
          ethers,
          poolAddress,
          bob.address,
          _depositSymbol,
          _depositAmount.toString()
        );
      }
      if (_borrowAmount != 0) {
        await collateralModule.borrowCollateral(
          ethers,
          poolAddress,
          bob.address,
          _borrowSymbol,
          _borrowAmount.toString()
        );
      }
    }
  );
