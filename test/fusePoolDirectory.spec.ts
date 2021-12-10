import { ethers, network, deployments } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
// @ts-ignore
import Web3 from "web3";
import { poolAssets } from "./setUp";
import { Fuse } from "midas-sdk";
import { deploy, getContractsConfig, prepare } from "./utilities";
import { BigNumber } from "ethers";

use(solidity);

let deployedPoolAddress: string;

describe("FusePoolDirectory", function () {
  beforeEach(async function () {
    await deployments.fixture(); // ensure you start from a fresh deployments
  });

  describe("Deploy pool", async function () {
    it.only("should deploy the pool", async function () {
      const { alice, bob } = await ethers.getNamedSigners();
      const spoFactory = await ethers.getContractFactory("SimplePriceOracle", alice);
      const spo = await spoFactory.deploy();
      console.log('spo.address: ', spo.address);

      const compFactory = await ethers.getContractFactory("Comptroller", alice);
      const comp = await compFactory.deploy();
      console.log('comp.address: ', comp.address);

      const fpdWithSigner = await ethers.getContract("FusePoolDirectory", bob);
      const deployedPool = await fpdWithSigner.deployPool(
        "TEST",
        comp.address,
        true,
        "500000000000000000",
        100,
        "1100000000000000000",
        spo.address
      );
      expect(deployedPool).to.be.ok;
    });
  });

  it("should deploy pool from sdk", async function () {
    await prepare(this, [["SimplePriceOracle", "bob"]]);
    await deploy(this, [["spo", this.SimplePriceOracle]]);

    const contractConfig = await getContractsConfig(network.name, this);
    const sdk = new Fuse(ethers.provider, contractConfig);

    const [poolAddress, implementationAddress, priceOracleAddress] = await sdk.deployPool(
      "TEST",
      true,
      BigNumber.from("500000000000000000"),
      2,
      BigNumber.from("1100000000000000000"),
      this.spo.address,
      {},
      { from: this.bob.address },
      [this.bob.address]
    );
    console.log(
      `Pool with address: ${poolAddress}, \ncomptroller address: ${implementationAddress}, \noracle address: ${priceOracleAddress} deployed`
    );
    deployedPoolAddress = poolAddress;
    expect(poolAddress).to.be.ok;
    expect(implementationAddress).to.be.ok;
  });
  it("should deploy assets to pool", async function () {
    const contractConfig = await getContractsConfig(network.name, this);
    const sdk = new Fuse(ethers.provider, contractConfig);
    const assets = poolAssets(this.jrm.address, deployedPoolAddress);

    for (const assetConf of assets.assets) {
      const [assetAddress, implementationAddress, receipt] = await sdk.deployAsset(
        Fuse.JumpRateModelConf,
        assetConf.collateralFactor,
        assetConf.reserveFactor,
        assetConf.adminFee,
        { from: this.bob.address },
        true
      );
      console.log("-----------------");
      console.log("deployed asset: ", assetConf.name);
      console.log("Asset Address: ", assetAddress);
      console.log("Implementation Address: ", implementationAddress);
      console.log("TX Receipt: ", receipt.hash);
      console.log("-----------------");
    }
  });
});
