import { expect } from "chai";
import { constants, Contract, providers, utils } from "ethers";
import { deployments, ethers } from "hardhat";
import { createPool, setUpPriceOraclePrices } from "./utils";
import { assetInPool, deployAssets, getPoolAssets, getPoolIndex } from "./utils/pool";
import { Fuse, USDPricedFuseAsset } from "../src";
import { chainDeployConfig } from "../chainDeploy";
import { getOrCreateFuse } from "./utils/fuseSdk";

describe("Deposit flow tests", function () {
  let sdk: Fuse;

  this.beforeEach(async () => {
    const { chainId } = await ethers.provider.getNetwork();
    if (chainId === 1337) {
      await deployments.fixture("prod");
    }
    await setUpPriceOraclePrices();
  });

  describe("Deposit flow", async function () {
    let poolAddress: string;

    beforeEach(async () => {
      this.timeout(120_000);
      const { bob } = await ethers.getNamedSigners();
      sdk = await getOrCreateFuse();
      [poolAddress] = await createPool({});
      const assets = await getPoolAssets(poolAddress, sdk.contracts.FuseFeeDistributor.address);
      await deployAssets(assets.assets, bob);
    });

    it("should enable native asset as collateral into pool and supply", async function () {
      let tx: providers.TransactionResponse;
      let rec: providers.TransactionReceipt;
      let cToken: Contract;
      let ethAsset: USDPricedFuseAsset;
      let ethAssetAfterBorrow: USDPricedFuseAsset;
      const { bob } = await ethers.getNamedSigners();
      const { chainId } = await ethers.provider.getNetwork();

      const poolId = (await getPoolIndex(poolAddress, sdk)).toString();
      const assetsInPool = await sdk.fetchFusePoolData(poolId);

      for (const asset of assetsInPool.assets) {
        if (asset.underlyingToken === constants.AddressZero) {
          cToken = new Contract(asset.cToken, sdk.chainDeployment.CEtherDelegate.abi, bob);
          const pool = await ethers.getContractAt("Comptroller.sol:Comptroller", poolAddress, bob);
          tx = await pool.enterMarkets([asset.cToken]);
          await tx.wait();
          tx = await cToken.mint({ value: utils.parseUnits("2", 18) });
          rec = await tx.wait();
          expect(rec.status).to.eq(1);
        } else {
          cToken = new Contract(asset.cToken, sdk.chainDeployment.CErc20Delegate.abi, bob);
        }
      }

      ethAsset = await assetInPool(poolId, sdk, chainDeployConfig[chainId].config.nativeTokenSymbol, bob.address);
      const cEther = new Contract(ethAsset.cToken, sdk.chainDeployment.CEtherDelegate.abi, bob);
      tx = await cEther.callStatic.borrow(utils.parseUnits("1.5", 18));
      expect(tx).to.eq(0);
      tx = await cEther.callStatic.borrow(1);
      expect(tx).to.eq(1019);
      tx = await cEther.borrow(utils.parseUnits("1.5", 18));
      rec = await tx.wait();
      expect(rec.status).to.eq(1);
      ethAssetAfterBorrow = await assetInPool(
        poolId,
        sdk,
        chainDeployConfig[chainId].config.nativeTokenSymbol,
        bob.address
      );
      expect(ethAsset.borrowBalance.lt(ethAssetAfterBorrow.borrowBalance)).to.eq(true);
      console.log(ethAssetAfterBorrow.borrowBalanceUSD, "Borrow Balance USD: AFTER mint & borrow");
      console.log(ethAssetAfterBorrow.supplyBalanceUSD, "Supply Balance USD: AFTER mint & borrow");
    });
  });
});
