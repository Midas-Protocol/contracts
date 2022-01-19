import { ethers } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
import { Fuse } from "../lib/esm/src";
import { constants, utils } from "ethers";
import { poolAssets } from "./utils";
import { DeployedAsset } from "./utils/pool";

use(solidity);

describe("FusePoolDirectory", function () {
  describe("Deploy pool", async function () {
    it.only("should deploy pool from sdk without whitelist", async function () {
      this.timeout(120_000);
      const POOL_NAME = "TEST_BOB";
      const { bob, deployer } = await ethers.getNamedSigners();

      const spoFactory = await ethers.getContractFactory("MockPriceOracle", bob);
      const spo = await spoFactory.deploy([10]);

      const sdk = new Fuse(ethers.provider, "1337");

      // 50% -> 0.5 * 1e18
      const bigCloseFactor = utils.parseEther((50 / 100).toString());
      // 8% -> 1.08 * 1e8
      const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());

      const [poolAddress, implementationAddress, priceOracleAddress] = await sdk.deployPool(
        POOL_NAME,
        false,
        bigCloseFactor,
        bigLiquidationIncentive,
        spo.address,
        {},
        { from: bob.address },
        []
      );
      console.log(
        `Pool with address: ${poolAddress}, \noracle address: ${priceOracleAddress} deployed\nimplementation address: ${implementationAddress}`
      );
      expect(poolAddress).to.be.ok;
      expect(implementationAddress).to.be.ok;

      const allPools = await sdk.contracts.FusePoolDirectory.callStatic.getAllPools();
      const { comptroller, name: _unfiliteredName } = await allPools
        .filter((p: { name: string }) => p.name === POOL_NAME)
        .at(-1);

      expect(_unfiliteredName).to.be.equal(POOL_NAME);

      const jrm = await ethers.getContract("JumpRateModel", bob);
      const assets = await poolAssets(jrm.address, comptroller, bob);

      const deployedAssets: DeployedAsset[] = [];
      for (const assetConf of assets.assets) {
        const [assetAddress, cTokenImplementationAddress, irmModel, receipt] = await sdk.deployAsset(
          Fuse.JumpRateModelConf,
          assetConf,
          { from: bob.address }
        );
        console.log("-----------------");
        console.log("deployed asset: ", assetConf.name);
        console.log("Asset Address: ", assetAddress);
        console.log("irmModel: ", irmModel);
        console.log("Implementation Address: ", cTokenImplementationAddress);
        console.log("TX Receipt: ", receipt.transactionHash);
        console.log("-----------------");
        deployedAssets.push({
          assetAddress,
          implementationAddress: cTokenImplementationAddress,
          interestRateModel: irmModel,
          receipt,
          symbol: assetConf.symbol,
          underlying: assetConf.underlying,
        });
      }
      const [totalSupply, totalBorrow, underlyingTokens, underlyingSymbols, whitelistedAdmin] =
        await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);

      expect(underlyingSymbols).to.have.members(["ETH", "TOUCH", "TRIBE"]);

      const fusePoolData = await sdk.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(poolAddress);
      expect(fusePoolData.length).to.eq(3);
      expect(fusePoolData.at(-1)[3]).to.eq("TRIBE");

      const native = deployedAssets.find((asset) => asset.underlying === constants.AddressZero);
      expect(native).to.be.ok;
      const pool = await ethers.getContractAt("Comptroller", poolAddress, bob);
      let res = await pool.enterMarkets([native.assetAddress]);
      let rec = await res.wait();

      // look in AmountSelect.tsx to see how this is supposed to work

      // SILENTLY SEEMS TO FAIL?
      const cEther = await ethers.getContractAt("CEther", native.assetAddress, bob);
      res = await cEther.mint({ value: 12345 });
      rec = await res.wait();
      expect(rec.status).to.eq(1);

      const token = deployedAssets.find((asset) => asset.symbol === "TRIBE");
      expect(token).to.be.ok;
      const tokenContract = await ethers.getContract("TRIBEToken", bob);
      const balance = await tokenContract.balanceOf(deployer.address);
      console.log('balance: ', balance);

      // this doesnt error even though nothing is approved, i dont have balance
      const cToken = await ethers.getContractAt("CErc20", token.assetAddress, bob);
      res = await cToken.mint(12345); // WHY DOESNT THIS ERROR
      rec = await res.wait();
      expect(rec.status).to.eq(1);

      const data = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);
      console.log("data: ", data);
    });
  });
});
