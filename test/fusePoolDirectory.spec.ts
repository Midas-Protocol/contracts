import { deployments, ethers, network } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
// @ts-ignore
import Web3 from "web3";
import { poolAssets } from "./setUp";
import { Fuse } from "../lib/esm";
import { getContractsConfig } from "./utilities";
import { BigNumber, utils } from "ethers";

use(solidity);

let deployedPoolAddress: string;

describe("FusePoolDirectory", function () {
  beforeEach(async function () {
    await deployments.fixture(); // ensure you start from a fresh deployments
  });

  describe("Deploy pool", async function () {
    it("should deploy the pool via contract", async function () {
      const { alice } = await ethers.getNamedSigners();
      const contractConfig = await getContractsConfig(network.name);

      const spoFactory = await ethers.getContractFactory("SimplePriceOracle", alice);
      const spo = await spoFactory.deploy();
      console.log("spo.address: ", spo.address);

      const fpdWithSigner = await ethers.getContract("FusePoolDirectory", alice);
      const maxAssets = "20";
      // 50% -> 0.5 * 1e18
      const bigCloseFactor = utils.parseUnits((50 / 100).toString());
      // 8% -> 1.08 * 1e8
      const bigLiquidationIncentive = utils.parseUnits((8 / 100 + 1).toString());
      const deployedPool = await fpdWithSigner.deployPool(
        "TEST",
        contractConfig.COMPOUND_CONTRACT_ADDRESSES.Comptroller,
        true,
        bigCloseFactor,
        maxAssets,
        bigLiquidationIncentive,
        spo.address
      );
      expect(deployedPool).to.be.ok;
    });

    it("should deploy pool from sdk", async function () {
      const { bob } = await ethers.getNamedSigners();

      const spoFactory = await ethers.getContractFactory("SimplePriceOracle", bob);
      const spo = await spoFactory.deploy();

      const contractConfig = await getContractsConfig(network.name);
      const sdk = new Fuse(ethers.provider, contractConfig);

      const [poolAddress, implementationAddress, priceOracleAddress] = await sdk.deployPool(
        "TEST",
        true,
        BigNumber.from("500000000000000000").toString(),
        20,
        BigNumber.from("1100000000000000000").toString(),
        spo.address,
        {},
        { from: bob.address },
        [bob.address]
      );
      console.log(
        `Pool with address: ${poolAddress}, \ncomptroller address: ${implementationAddress}, \noracle address: ${priceOracleAddress} deployed`
      );
      deployedPoolAddress = poolAddress;
      expect(poolAddress).to.be.ok;
      expect(implementationAddress).to.be.ok;
    });

    it("should deploy assets to pool", async function () {
      const { alice, bob } = await ethers.getNamedSigners();

      const jrm = await ethers.getContract("JumpRateModel", alice);
      const contractConfig = await getContractsConfig(network.name);
      const sdk = new Fuse(ethers.provider, contractConfig);
      const assets = poolAssets(jrm.address, deployedPoolAddress);

      for (const assetConf of assets.assets) {
        const [assetAddress, implementationAddress, irmModel, receipt] = await sdk.deployAsset(
          Fuse.JumpRateModelConf,
          assetConf,
          { from: bob.address }
        );
        console.log("-----------------");
        console.log("deployed asset: ", assetConf.name);
        console.log("Asset Address: ", assetAddress);
        console.log("Implementation Address: ", implementationAddress);
        // @ts-ignore
        console.log("TX Receipt: ", receipt.transactionHash);
        console.log("-----------------");
      }
    });
  });
});
