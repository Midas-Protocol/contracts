import { task } from "hardhat/config";
import { cERC20Conf, Fuse } from "../src";

task("fixtures", "Deploys demo fixture pools").setAction(async (_, hre) => {
  // Setup
  if (hre.network.name != "localhost") {
    console.log(`This task is build for localhost use only.\nContext: ${hre.network.name}`);
    return;
  }
  const { ethers } = hre;
  const { utils } = ethers;
  const sdk = new Fuse(ethers.provider, "1337");

  const { alice } = await ethers.getNamedSigners();

  // Deploy Pol
  const spoFactory = await ethers.getContractFactory("MockPriceOracle", alice);
  const spo = await spoFactory.deploy([10]);
  // 50% -> 0.5 * 1e18
  const bigCloseFactor = utils.parseEther((50 / 100).toString());
  // 8% -> 1.08 * 1e8
  const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());

  const POOL_NAME = "Fixture Pool of Alice";
  const [poolAddress, implementationAddress, priceOracleAddress] = await sdk.deployPool(
    POOL_NAME,
    false,
    bigCloseFactor,
    bigLiquidationIncentive,
    spo.address,
    {},
    { from: alice.address },
    []
  );
  console.log(
    `Pool with address: ${poolAddress}, \noracle address: ${priceOracleAddress} deployed\nimplementation address: ${implementationAddress}`
  );

  // Deploy Assets
  const allPools = await sdk.contracts.FusePoolDirectory.callStatic.getAllPools();
  const { comptroller } = await allPools.filter((p) => p.name === POOL_NAME).at(-1);

  const jrm = await ethers.getContract("JumpRateModel", alice);

  const touchConf: cERC20Conf = {
    underlying: await ethers.getContract("TOUCHToken", alice).then((c) => c.address),
    comptroller,
    interestRateModel: jrm.address,
    name: "Midas TOUCH Token",
    symbol: "TOUCH",
    decimals: 18,
    admin: "true",
    collateralFactor: 65,
    reserveFactor: 20,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };

  const ethConf: cERC20Conf = {
    underlying: "0x0000000000000000000000000000000000000000",
    comptroller,
    interestRateModel: jrm.address,
    name: "Ethereum",
    symbol: "ETH",
    decimals: 8,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 20,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };

  const tribeConf: cERC20Conf = {
    underlying: await ethers.getContract("TRIBEToken", alice).then((c) => c.address),
    comptroller,
    interestRateModel: jrm.address,
    name: "TRIBE Token",
    symbol: "TRIBE",
    decimals: 18,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 15,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };

  for (const assetConf of [ethConf, touchConf, tribeConf]) {
    await sdk.deployAsset(Fuse.JumpRateModelConf, assetConf, { from: alice.address });
  }

  // TODO enter market
  // TODO abstract and create two pools with different owners and assets and models
});
