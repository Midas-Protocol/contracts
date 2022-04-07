import { deployments, ethers } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
import { Fuse } from "../../src";
import { setUpPriceOraclePrices } from "../utils";
import { getOrCreateFuse } from "../utils/fuseSdk";
import * as poolHelpers from "../utils/pool";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

use(solidity);

describe("FusePoolsModule", function () {
  let poolAddress: string;
  let sdk: Fuse;
  let deployer: SignerWithAddress;

  this.beforeEach(async () => {
    await deployments.fixture("prod");
    await setUpPriceOraclePrices();
    deployer = (await ethers.getNamedSigners()).deployer;

    sdk = await getOrCreateFuse();

    [poolAddress] = await poolHelpers.createPool({ signer: deployer, poolName: "Fetching-Pools-Test" });
    const assets = await poolHelpers.getPoolAssets(poolAddress, sdk.contracts.FuseFeeDistributor.address);
    await poolHelpers.deployAssets(assets.assets, deployer);
  });

  describe("fetch pools", async function () {
    it("user can fetch all pools", async function () {
      const pools = await sdk.fetchPoolsManual({ verification: false, coingeckoId: "ethereum", options: { from: deployer.address } });
      expect(pools.length).to.equal(1);
      expect(pools[0].creator).to.equal(deployer.address);
      expect(pools[0].name).to.equal('Fetching-Pools-Test');
      expect(pools[0].totalLiquidityUSD).to.equal(0);
      expect(pools[0].totalSuppliedUSD).to.equal(0);
      expect(pools[0].totalBorrowedUSD).to.equal(0);
      expect(pools[0].totalSupplyBalanceUSD).to.equal(0);
      expect(pools[0].totalBorrowBalanceUSD).to.equal(0);
    });

    it("user can fetch filtered pools", async function () {
      let pools = await sdk.fetchPools({ filter: 'created-pools', coingeckoId: "ethereum", options: { from: deployer.address } });
      expect(pools.length).to.equal(1);
      expect(pools[0].creator).to.equal(deployer.address);
      expect(pools[0].name).to.equal('Fetching-Pools-Test');
      expect(pools[0].totalLiquidityUSD).to.equal(0);
      expect(pools[0].totalSuppliedUSD).to.equal(0);
      expect(pools[0].totalBorrowedUSD).to.equal(0);
      expect(pools[0].totalSupplyBalanceUSD).to.equal(0);
      expect(pools[0].totalBorrowBalanceUSD).to.equal(0);

      pools = await sdk.fetchPools({ filter: 'verified-pools', coingeckoId: "ethereum", options: { from: deployer.address } });
      expect(pools).to.equal(undefined);

      pools = await sdk.fetchPools({ filter: 'unverified-pools', coingeckoId: "ethereum", options: { from: deployer.address } });
      expect(pools.length).to.equal(1);

      pools = await sdk.fetchPools({ filter: 'random-filter', coingeckoId: "ethereum", options: { from: deployer.address } });
      expect(pools.length).to.equal(1);
    });
  });
});
