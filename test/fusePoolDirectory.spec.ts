import { ethers, network } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
// @ts-ignore
import Web3 from "web3";
import { poolAssets } from "./setUp";
import { Fuse } from "../sdk/fuse-sdk";
import { deploy, getContractsConfig, prepare, initializeWithWhitelist } from "./utilities";

use(solidity);

let deployedPoolAddress;

describe("FusePoolDirectory", function () {
  before(async function () {
    await prepare(this, [
      ["FusePoolDirectory", null],
      ["FuseFeeDistributor", null],
      ["Comptroller", null],
      ["JumpRateModel", null],
    ]);

    await deploy(this, [
      ["fpd", this.FusePoolDirectory],
      ["ffd", this.FuseFeeDistributor],
      ["comp", this.Comptroller],
      [
        "jrm",
        this.JumpRateModel,
        [
          "20000000000000000", // baseRatePerYear
          "200000000000000000", // multiplierPerYear
          "2000000000000000000", //jumpMultiplierPerYear
          "900000000000000000", // kink
        ],
      ],
    ]);
    await initializeWithWhitelist(this);
  });

  describe("Deploy pool", async function () {
    it("should deploy the pool", async function () {
      await prepare(this, [["SimplePriceOracle", "alice"]]);
      await deploy(this, [["spo", this.SimplePriceOracle]]);

      const fdpWithSigner = await this.fpd.connect(this.bob);
      const deployedPool = await fdpWithSigner.deployPool(
        "TEST",
        this.comp.address,
        true,
        "500000000000000000",
        "1100000000000000000",
        this.spo.address
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
      "500000000000000000",
      2,
      "1100000000000000000",
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
      const [assetAddress, implementationAddress, receipt] = await sdk.deployAsset(Fuse.JumpRateModelConf, assetConf, {
        from: this.bob.address,
      });
      console.log("-----------------");
      console.log("deployed asset: ", assetConf.name);
      console.log("Asset Address: ", assetAddress);
      console.log("Implementation Address: ", implementationAddress);
      console.log("TX Receipt: ", receipt.hash);
      console.log("-----------------");
    }
  });
});
