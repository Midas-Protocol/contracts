import { parseEther } from "ethers/lib/utils";
import { task, types } from "hardhat/config";

// npx hardhat pool:create --name Test --creator deployer --price-oracle 0x2D293ef3309557cD645a0D0f480ab2f3C4411846 --close-factor 50 --liquidation-incentive 8 --enforce-whitelist false --network localhost

task("pool:create", "Create pool if does not exist")
  .addParam("name", "Name of the pool to be created", undefined, types.string)
  .addParam("creator", "Named account from which to create the pool", "deployer", types.string)
  .addParam("priceOracle", "Which price oracle to use", undefined, types.string)
  .addParam("closeFactor", "Close factor in full percent (50% = 50)", undefined, types.string)
  .addParam("liquidationIncentive", "Liquidation incentive in full percent (8% = 8)", undefined, types.string)
  .addParam("enforceWhitelist", "Whitelist enabled?", undefined, types.string)
  .addOptionalParam("whitelist", "whitelist as comma separated input (address1,address2...)", undefined, types.string)
  .setAction(async (taskArgs, hre) => {
    const signer = await hre.ethers.getNamedSigner(taskArgs.creator);

    // @ts-ignore
    const poolModule = await import("../test/utils/pool");
    // @ts-ignore
    const fuseModule = await import("../test/utils/fuseSdk");
    const sdk = await fuseModule.getOrCreateFuse();
    const whitelist = taskArgs.whitelist ? taskArgs.whitelist.split(",") : [];
    if (taskArgs.enforceWhitelist === "true" && whitelist.length === 0) {
      throw "If enforcing whitelist, a whitelist array of addresses must be provided";
    }

    let poolAddress: string;
    if (await poolModule.getPoolByName(taskArgs.name, sdk)) {
      throw "Pool already exists";
    } else {
      [poolAddress, , ,] = await sdk.deployPool(
        taskArgs.name,
        taskArgs.enforceWhitelist === "true",
        parseEther((Number(taskArgs.closeFactor) / 100).toString()),
        parseEther((Number(taskArgs.liquidationIncentive) / 100 + 1).toString()),
        taskArgs.priceOracle,
        {},
        { from: signer.address },
        whitelist
      );
    }

    await poolModule.logPoolData(poolAddress, sdk);
    return poolAddress;
  });
