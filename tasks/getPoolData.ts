import { task, types } from "hardhat/config";

export default task("get-pool-data", "Get pools data")
  .addOptionalParam("name", "Name of the pool", undefined, types.string)
  .addOptionalParam("creator", "Named account that created the pool", undefined, types.string)
  .addOptionalParam("address", "Address of the pool", undefined, types.string)
  .setAction(async (taskArgs, hre) => {
    // @ts-ignore
    const sdkModule = await import("../src");
    // @ts-ignore
    const poolModule = await import("../test/utils/pool");
    // @ts-ignore
    const fuseTestModule = await import("../test/utils/fuseSdk");

    const chainId = parseInt(await hre.getChainId());
    if (!(chainId in sdkModule.SupportedChains)) {
      throw "Invalid chain provided";
    }
    let chainDeployment = {};
    if (chainId === 1337) {
      chainDeployment = await fuseTestModule.getLocalDeployments();
    }
    const sdk = new sdkModule.Fuse(hre.ethers.provider, chainId, chainDeployment);
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
    // @ts-ignore
    const fuseTestModule = await import("../test/utils/fuseSdk");

    const chainId = parseInt(await hre.getChainId());
    if (!(chainId in sdkModule.SupportedChains)) {
      throw "Invalid chain provided";
    }
    let chainDeployment = {};
    if (chainId === 1337) {
      chainDeployment = await fuseTestModule.getLocalDeployments();
    }
    const sdk = new sdkModule.Fuse(hre.ethers.provider, chainId, chainDeployment);

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

task("get-public-pools", "Get public pools").setAction(async ({}, { ethers, getNamedAccounts }) => {
  const { deployer } = await getNamedAccounts();

  const fpd = await ethers.getContract("FusePoolLens", deployer);
  const pools = await fpd.callStatic.getPublicPoolsWithData();
  console.log("pools: ", pools);
});

task("get-balance-of", "Get public pools")
  .addOptionalParam("name", "Name of the pool", "deployer", types.string)
  .addOptionalParam("tokenAddress", "Address of token", undefined, types.string)
  .setAction(async (taskArgs, hre) => {
    const signer = await hre.ethers.getNamedSigner(taskArgs.name);
    if (!taskArgs.tokenAddress) {
      console.log("balance: ", hre.ethers.utils.formatEther(await signer.getBalance()));
    } else {
      const token = await hre.ethers.getContractAt("EIP20Interface", taskArgs.tokenAddress);
      console.log("balance: ", hre.ethers.utils.formatEther(await token.balanceOf(signer.address)));
    }
  });
