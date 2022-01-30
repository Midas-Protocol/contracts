import { task, types } from "hardhat/config";

const logPoolData = async (poolAddress, sdk) => {
  const poolModule = await import("../test/utils/pool");
  const poolIndex = await poolModule.getPoolIndex(poolAddress, sdk);
  const fusePoolData = await sdk.fetchFusePoolData(poolIndex, poolAddress);

  const poolAssets = fusePoolData.assets.map((a) => a.underlyingSymbol).join(", ");
  console.log(`Operating on pool with address ${poolAddress}, name: ${fusePoolData.name}, assets ${poolAssets}`);
};

export default task("pools", "Create Testing Pools")
  .addParam("name", "Name of the pool to be created")
  .addOptionalParam("creator", "Named account from which to create the pool", "deployer", types.string)
  .addOptionalParam("depositAmount", "Amount to deposit", 0, types.int)
  .addOptionalParam("depositSymbol", "Symbol of token to deposit", "ETH")
  .addOptionalParam("depositAccount", "Named account from which to deposit collateral", "deployer", types.string)
  .addOptionalParam("borrowAmount", "Amount to borrow", 0, types.int)
  .addOptionalParam("borrowSymbol", "Symbol of token to borrow", "ETH")
  .addOptionalParam("borrowAccount", "Named account from which to borrow collateral", "deployer", types.string)
  .setAction(async (taskArgs, hre) => {
    const poolAddress = await hre.run("pools:create", { name: taskArgs.name, creator: taskArgs.creator });
    if (taskArgs.depositAmount != 0) {
      await hre.run("pools:deposit", {
        amount: taskArgs.depositAmount,
        symbol: taskArgs.depositSymbol,
        account: taskArgs.depositAccount,
        poolAddress,
      });
    }
    if (taskArgs.borrowAmount != 0) {
      await hre.run("pools:borrow", {
        amount: taskArgs.borrowAmount,
        symbol: taskArgs.borrowSymbol,
        account: taskArgs.borrowAccount,
        poolAddress,
      });
    }
  });

task("pools:create", "Create pool if does not exist")
  .addParam("name", "Name of the pool to be created")
  .addParam("creator", "Named account from which to create the pool", "deployer", types.string)
  .setAction(async (taskArgs, hre) => {
    const poolModule = await import("../test/utils/pool");
    // @ts-ignore
    const sdkModule = await import("../lib/esm/src");

    const sdk = new sdkModule.Fuse(hre.ethers.provider, "1337");
    const account = await hre.ethers.getNamedSigner(taskArgs.creator);
    const existingPool = await poolModule.getPoolByName(taskArgs.name, sdk);

    let poolAddress: string;
    if (existingPool !== null) {
      console.log(`Pool with name ${existingPool.name} exists already, will operate on it`);
      poolAddress = existingPool.comptroller;
    } else {
      [poolAddress] = await poolModule.createPool({ ethers: hre.ethers, poolName: taskArgs.name, signer: account });
      const assets = await poolModule.getAssetsConf(hre.ethers, poolAddress);
      await poolModule.deployAssets(hre.ethers, assets.assets, account);
    }
    await logPoolData(poolAddress, sdk);
    return poolAddress;
  });

task("pools:borrow", "Borrow collateral")
  .addParam("account", "Account from which to borrow", "deployer", types.string)
  .addParam("amount", "Amount to borrow", 0, types.int)
  .addParam("symbol", "Symbol of token to be borrowed", "ETH")
  .addParam("poolAddress", "Address of the poll")
  .setAction(async (taskArgs, hre) => {
    const collateralModule = await import("../test/utils/collateral");
    const account = await hre.ethers.getNamedSigner(taskArgs.account);
    await collateralModule.borrowCollateral(
      hre.ethers,
      taskArgs.poolAddress,
      account.address,
      taskArgs.symbol,
      taskArgs.amount.toString()
    );
  });

task("pools:deposit", "Deposit collateral")
  .addParam("account", "Account from which to borrow", "deployer", types.string)
  .addParam("amount", "Amount to deposit", 0, types.int)
  .addParam("symbol", "Symbol of token to be deposited", "ETH")
  .addParam("poolAddress", "Address of the poll")
  .setAction(async (taskArgs, hre) => {
    const collateralModule = await import("../test/utils/collateral");
    const account = await hre.ethers.getNamedSigner(taskArgs.account);
    await collateralModule.addCollateral(
      hre.ethers,
      taskArgs.poolAddress,
      account.address,
      taskArgs.symbol,
      taskArgs.amount.toString()
    );
  });

task("pools:create-unhealthy", "Deposit collateral")
  .addParam("name", "Name of the pool to be created if does not exist")
  .addParam("supplyAccount", "Account from which to supply", "deployer", types.string)
  .addParam("borrowAccount", "Account from which to borrow", "alice", types.string)
  .addParam("borrowToken", "Token used to borrow", "ETH")
  .addParam("collateralToken", "name used as collateral", "TOUCH")
  .setAction(async (taskArgs, hre) => {
    await hre.run("set-price", { token: "ETH", price: "1" });
    await hre.run("set-price", { token: "TOUCH", price: "0.1" });
    await hre.run("set-price", { token: "TRIBE", price: "0.2" });

    const poolAddress = await hre.run("pools:create", { name: taskArgs.name });

    // Supply ETH collateral from bob
    await hre.run("pools:deposit", {
      account: taskArgs.supplyAccount,
      amount: 5,
      symbol: "ETH",
      poolAddress,
    });
    console.log("ETH deposited");

    // Supply TOUCH collateral from alice
    await hre.run("pools:deposit", {
      account: taskArgs.borrowAccount,
      amount: 50,
      symbol: "TOUCH",
      poolAddress,
    });
    console.log("TOUCH deposited");

    // Borrow TOUCH with ETH as collateral from bob
    await hre.run("pools:borrow", {
      account: taskArgs.supplyAccount,
      amount: 20,
      symbol: "TOUCH",
      poolAddress,
    });

    await hre.run("set-price", { token: "ETH", price: "0.1", poolAddress });
  });
