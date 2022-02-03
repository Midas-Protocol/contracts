import { task, types } from "hardhat/config";

export default task("get-pool-data", "Get pools data")
  .addOptionalParam("name", "Name of the pool", undefined, types.string)
  .addOptionalParam("creator", "Named account that created the pool", undefined, types.string)
  .addOptionalParam("address", "Address of the pool", undefined, types.string)
  .setAction(async (taskArgs, hre) => {
    const sdkModule = await import("../lib/esm/src");
    const poolModule = await import("../test/utils/pool");

    const chainId = parseInt(await hre.getChainId());
    if (!(chainId in sdkModule.SupportedChains)) {
      throw "Invalid chain provided";
    }
    const sdk = new sdkModule.Fuse(hre.ethers.provider, chainId);
    if (taskArgs.address) {
      const pool = await poolModule.logPoolData(taskArgs.address, sdk);
      console.log(pool);
      return;
    }
    if (taskArgs.name) {
      const pool = await poolModule.getPoolByName(taskArgs.name, sdk);
      console.log(pool);
      return;
    }
    if (taskArgs.creator) {
      const account = await hre.ethers.getNamedSigner(taskArgs.creator);
      const pools = await sdk.contracts.FusePoolLens.callStatic.getPoolsByAccountWithData(account.address);
      console.log(pools);
      return;
    }
    if (!taskArgs.name && !taskArgs.creator) {
      const fpd = await hre.ethers.getContract("FusePoolLens", (await hre.ethers.getNamedSigner("deployer")).address);
      console.log(await fpd.directory());
      const pools = await sdk.contracts.FusePoolLens.callStatic.getPublicPoolsWithData();
      console.log(pools);
      return;
    }
  });
