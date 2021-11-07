import { ethers } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
// @ts-ignore
import { poolAssets, setUpTest } from "./setUp";
import Fuse from "../sdk/fuse-sdk";
import { Contract } from "@ethersproject/contracts";
import { Big } from "big.js";

use(solidity);

let comptroller: Contract;
let deployedPoolAddress: string;

before(async () => {
  await setUpTest();
});

describe("FusePoolDirectory", () => {
  it("should deploy the pool", async () => {
    const deployer = await ethers.getNamedSigner("deployer");
    const alice = await ethers.getNamedSigner("alice");

    comptroller = await ethers.getContract("Comptroller", deployer);

    const priceOracleFactory = await ethers.getContractFactory(
      "SimplePriceOracle",
      deployer
    );
    const priceOracle = await priceOracleFactory.deploy();
    expect(priceOracle.address).to.be.ok;

    const fusePoolDirectory = await ethers.getContract(
      "FusePoolDirectory",
      alice
    );
    expect(fusePoolDirectory.address).to.be.ok;

    const deploy = await fusePoolDirectory.functions.deployPool(
      "TEST",
      comptroller.address,
      true,
      "500000000000000000",
      "1100000000000000000",
      priceOracle.address
    );

    console.log("deploy: ", deploy);
  });
});

describe("SDK deployPool", () => {
  it("should deploy the pool", async () => {
    const bob = await ethers.getNamedSigner("bob");

    const sdk = new Fuse("http://localhost:8545");
    const priceOracleFactory = await ethers.getContractFactory(
      "SimplePriceOracle",
      bob
    );

    const oracle = await priceOracleFactory.deploy();

    const [poolAddress, implementationAddress, priceOracleAddress] =
      await sdk.deployPool(
        "TEST",
        true,
        "500000000000000000",
        "1100000000000000000",
        oracle.address,
        {},
        { from: bob.address },
        [bob.address]
      );
    deployedPoolAddress = poolAddress;
    console.log(
      `Pool with address: ${poolAddress}, \ncomptroller address: ${implementationAddress}, \noracle address: ${priceOracleAddress} deployed`
    );
    expect(poolAddress).to.be.ok;
    expect(implementationAddress).to.be.ok;
  });

  it("should get pool directory past events", async () => {
    const bob = await ethers.getNamedSigner("bob");
    const sdk = new Fuse("http://localhost:8545");
    const events = (
      await sdk.contracts.FusePoolDirectory.getPastEvents("PoolRegistered", {
        fromBlock: "earliest",
        toBlock: "latest",
      })
    ).filter(
      (event) =>
        event.returnValues.pool.creator.toLowerCase() ===
        bob.address.toLowerCase()
    )[0];
    expect(events.returnValues.pool.name).to.be.eq("TEST");
  });
});

describe("SDK deployAsset", () => {
  it("should deploy the asset to the pool", async () => {
    const bob = await ethers.getNamedSigner("bob");
    const sdk = new Fuse("http://localhost:8545");

    const assets = poolAssets.assets;
    for (const asset of assets) {
      const poolConfig = {
        name: poolAssets.shortName + ": " + asset.underlying,
        symbol: poolAssets.assetSymbolPrefix + asset.underlyingSymbol,
        underlying: asset.underlying,
        collateralFactor: asset.collateralFactor,
        reserveFactor: asset.reserveFactor,
        interestRateModel: asset.interestRateModel,
        comptroller: deployedPoolAddress,
        admin: bob.address,
        adminFee: Fuse.Web3.utils.toBN(0),
      };

      const [assetAddress, implementationAddress, interestRateModel, receipt] =
        await sdk.deployAsset(
          poolConfig,
          Fuse.Web3.utils.toBN(
            new Big(poolConfig.collateralFactor)
              .mul(new Big(10).pow(18))
              .toFixed(0)
          ),
          Fuse.Web3.utils.toBN(
            new Big(poolConfig.reserveFactor)
              .mul(new Big(10).pow(18))
              .toFixed(0)
          ),
          poolConfig.adminFee,
          { from: bob.address },
          true
        );
      console.log(
        "deployed asset: ",
        assetAddress,
        implementationAddress,
        interestRateModel,
        receipt
      );
    }
  });
});
