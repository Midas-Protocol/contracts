import { expect } from "chai";
import { constants } from "ethers";
import { ethers } from "hardhat";
import { createPool } from "./utils";
import { deployAssets, DeployedAsset, getAssetsConf } from "./utils/pool";

describe("Deposit flow tests", function () {
  describe("Deposit flow", async function () {
    let poolImplementationAddress: string;
    let poolAddress: string
    let deployedAssets: DeployedAsset[]; 

    beforeEach(async () => {
      [poolAddress, poolImplementationAddress] = await createPool();
      console.log('poolImplementationAddress: ', poolImplementationAddress);
      console.log('poolAddress: ', poolAddress);
      const comptroller = await ethers.getContract("Comptroller");
      console.log('comptroller: ', comptroller.address);
      
      const assets = await getAssetsConf(poolImplementationAddress);
      deployedAssets = await deployAssets(assets.assets);
    });

    it("should enable native asset as collateral into pool and supply", async function () {
      const { bob } = await ethers.getNamedSigners();
      const pool = await ethers.getContractAt("Comptroller", poolImplementationAddress, bob);
      const native = deployedAssets.find((asset) => asset.underlying === constants.AddressZero);
      let res = await pool.enterMarkets([native.assetAddress]);
      let rec = await res.wait();
      expect(rec.status).to.eq(1);

      const fpd = await ethers.getContract("FusePoolDirectory", bob);
      const allPools = await fpd.callStatic.getAllPools();
      console.log('allPools: ', allPools);

      const cToken = await ethers.getContractAt("CEther", native.assetAddress, bob);
      res = await cToken.mint({ value: 12345 });
      rec = await res.wait();
      expect(rec.status).to.eq(1);

      const lens = await ethers.getContract("FusePoolLens");
      const data = await lens.callStatic.getPoolSummary(poolAddress);
      console.log('data: ', data);
    });
  });
});
