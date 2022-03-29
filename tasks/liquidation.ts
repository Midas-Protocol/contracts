import { task, types } from "hardhat/config";

export default task("get-liquidations", "Get potential liquidations")
  .addOptionalParam(
    "comptrollers",
    "Supported comptrollers for which to search for liquidations",
    undefined,
    types.string
  )
  .addOptionalParam("maxHealth", "Filter pools by max health", "1", types.string)
  .setAction(async (taskArgs, hre) => {
    // @ts-ignore
    const sdkModule = await import("../src");
    const chainId = parseInt(await hre.getChainId());
    if (!(chainId in sdkModule.SupportedChains)) {
      throw "Invalid chain provided";
    }
    const sdk = new sdkModule.Fuse(hre.ethers.provider, chainId);
    const liquidations = await sdk.getPotentialLiquidations([], hre.ethers.utils.parseEther(taskArgs.maxHealth));
    liquidations.map((l) => {
      console.log(`Found ${l.liquidations.length} liquidations for pool: ${l.comptroller}}`);
      l.liquidations.map((tx, i) => {
        console.log(`\n #${i}: method: ${tx.method}, args: ${tx.args}, value: ${tx.value}`);
      });
    });
  });
