import { expect } from "chai";
import { constants } from "ethers";
import { ethers } from "hardhat";
import { createPool } from "./utils";
import { deployAssets, DeployedAsset, getAssetsConf } from "./utils/pool";

describe("Deposit flow tests", function () {
  describe("Deposit flow", async function () {
    let poolComptrollerAddress: string;
    let deployedAssets: DeployedAsset[]; 

    beforeEach(async () => {
      [, poolComptrollerAddress] = await createPool();
      const assets = await getAssetsConf(poolComptrollerAddress);
      deployedAssets = await deployAssets(assets.assets);
    });

    it.only("should enable native asset as collateral into pool and supply", async function () {
      const { bob } = await ethers.getNamedSigners();
      const pool = await ethers.getContractAt("Comptroller", poolComptrollerAddress, bob);
      const native = deployedAssets.find((asset) => asset.underlying === constants.AddressZero);
      let res = await pool.enterMarkets([native.assetAddress]);
      let rec = await res.wait();
      expect(rec.status).to.eq(1);

      const cToken = await ethers.getContractAt("CEther", native.assetAddress, bob);
      res = await cToken.mint({ value: 12345 });
      rec = await res.wait();
      expect(rec.status).to.eq(1);

      const lens = await ethers.getContract("FusePoolLens");
      const data = await lens.callStatic.getPoolSummary(poolComptrollerAddress);
      console.log('data: ', data);
    });
  });
});
