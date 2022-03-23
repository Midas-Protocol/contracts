import { task, types } from "hardhat/config";

export default task("get-liquidations", "Get potential liquidations")
  .addOptionalParam(
    "comptrollers",
    "Supported comptrollers for which to search for liquidations",
    undefined,
    types.string
  )
  .addOptionalParam("creator", "Named account that created the pool", undefined, types.string)
  .setAction(async (taskArgs, hre) => {
    // @ts-ignore
    const sdkModule = await import("../src");
  });

task("get-position-ratio", "Get unhealthy po data")
  .addOptionalParam("name", "Name of the pool", undefined, types.string)
  .addOptionalParam("poolId", "Id of the pool", undefined, types.int)
  .addOptionalParam("namedUser", "Named account for which to query unhealthy positions", undefined, types.string)
  .addOptionalParam(
    "userAddress",
    "Account address of the user for which to query unhealthy positions",
    undefined,
    types.string
  )
  .addOptionalParam("cgId", "Coingecko id for the native asset", "ethereum", types.string)
  .addOptionalParam("logData", "Verbose logging", false, types.boolean)
  .setAction(async (taskArgs, hre) => {
    // @ts-ignore
    const sdkModule = await import("../src");
    // @ts-ignore
    const poolModule = await import("../test/utils/pool");

    const chainId = parseInt(await hre.getChainId());
    if (!(chainId in sdkModule.SupportedChains)) {
      throw "Invalid chain provided";
    }
    const sdk = new sdkModule.Fuse(hre.ethers.provider, chainId);

    if (!taskArgs.namedUser && !taskArgs.userAddress) {
      throw "Must provide either a named user or an account address";
    }
    if (!taskArgs.poolId && !taskArgs.name && taskArgs.poolId !== 0) {
      throw "Must provide either a pool name or a pool id";
    }

    let poolUser: string;
    let fusePoolData;

    if (taskArgs.namedUser) {
      poolUser = (await hre.ethers.getNamedSigner(taskArgs.namedUser)).address;
    } else {
      poolUser = taskArgs.userAddress;
    }

    fusePoolData = taskArgs.name
      ? await poolModule.getPoolByName(taskArgs.name, sdk, poolUser, taskArgs.cgId)
      : await sdk.fetchFusePoolData(taskArgs.poolId.toString(), poolUser, taskArgs.cgId);

    const maxBorrowR = fusePoolData.assets.map((a) => {
      const mult = parseFloat(hre.ethers.utils.formatUnits(a.collateralFactor, a.underlyingDecimals));
      if (taskArgs.logData) {
        console.log(
          a.underlyingSymbol,
          "\n supplyBalanceUSD: ",
          a.supplyBalanceUSD,
          "\n borrowBalanceUSD: ",
          a.borrowBalanceUSD,
          "\n totalSupplyUSD: ",
          a.totalSupplyUSD,
          "\n totalBorrowUSD: ",
          a.totalBorrowUSD,
          "\n Multiplier: ",
          mult,
          "\n Max Borrow Asset: ",
          mult * a.supplyBalanceUSD
        );
      }

      return a.supplyBalanceUSD * parseFloat(hre.ethers.utils.formatUnits(a.collateralFactor, a.underlyingDecimals));
    });
    const maxBorrow = maxBorrowR.reduce((a, b) => a + b, 0);
    const ratio = (fusePoolData.totalBorrowBalanceUSD / maxBorrow) * 100;
    console.log(`Ratio of total borrow / max borrow: ${ratio} %`);
    return ratio;
  });
