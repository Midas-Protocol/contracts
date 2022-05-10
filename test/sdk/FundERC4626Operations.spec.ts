import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import Fuse from "../../src/Fuse";
import { setUpPriceOraclePrices, tradeNativeForAsset } from "../utils";
import * as poolHelpers from "../utils/pool";
import { BigNumber, constants, providers, utils } from "ethers";
import { getOrCreateFuse } from "../utils/fuseSdk";
import { SimplePriceOracle } from "../../typechain/SimplePriceOracle";
import { tradeAssetForAsset } from "../utils/setup";

(process.env.FORK_CHAIN_ID ? describe.only : describe.skip)("FundOperationsERC4626Module", function () {
  let poolAddress: string;
  let sdk: Fuse;
  let chainId: number;
  let tx: providers.TransactionResponse;
  let rec: providers.TransactionReceipt;

  this.beforeEach(async () => {
    ({ chainId } = await ethers.provider.getNetwork());
    await deployments.fixture("prod");

    const { deployer } = await ethers.getNamedSigners();

    sdk = await getOrCreateFuse();

    [poolAddress] = await poolHelpers.createPool({
      signer: deployer,
      poolName: "Pool-Fund-Operations-Test",
    });

    const assets = await poolHelpers.getPoolAssets(poolAddress, sdk.contracts.FuseFeeDistributor.address);
    await setUpPriceOraclePrices(assets.assets.map((a) => a.underlying));
    const simpleOracle = (await ethers.getContractAt(
      "SimplePriceOracle",
      sdk.oracles.SimplePriceOracle.address,
      deployer
    )) as SimplePriceOracle;
    for (const a of assets.assets) {
      await simpleOracle.setDirectPrice(a.underlying, BigNumber.from(1));
    }
    await poolHelpers.deployAssets(assets.assets, deployer);

    const BTCB = assets.assets.find((a) => a.symbol === "BTCB");
    const BOMB = assets.assets.find((a) => a.symbol === "BOMB");
    const ETH = assets.assets.find((a) => a.symbol === "mETH");
    // acquire some test tokens
    await tradeNativeForAsset({ account: "bob", token: BTCB.underlying, amount: "500" });
    await tradeNativeForAsset({ account: "bob", token: ETH.underlying, amount: "100" });
    await tradeAssetForAsset({ account: "bob", token1: BTCB.underlying, token2: BOMB.underlying, amount: "0.2" });
  });

  it("user can supply any asset", async function () {
    const { bob } = await ethers.getNamedSigners();
    const poolId = (await poolHelpers.getPoolIndex(poolAddress, sdk)).toString();

    const assetsInPool = await sdk.fetchFusePoolData(poolId);
    const BTCB = assetsInPool.assets.find((asset) => asset.underlyingSymbol === "BTCB");
    const BOMB = assetsInPool.assets.find((asset) => asset.underlyingSymbol === "BOMB");
    const ETH = assetsInPool.assets.find((asset) => asset.underlyingSymbol === "ETH");

    const amounts = ["0.1", "1000", "4"];
    for (const [idx, asset] of [BTCB, BOMB, ETH].entries()) {
      console.log(`Supplying: ${asset.underlyingSymbol}`);
      const res = await sdk.supply(
        asset.cToken,
        asset.underlyingToken,
        poolAddress,
        asset.underlyingToken === constants.AddressZero || asset.underlyingToken === sdk.chainSpecificAddresses.W_TOKEN,
        true,
        utils.parseUnits(amounts[idx], 18),
        { from: bob.address }
      );
      tx = res.tx;
      rec = await tx.wait();
      expect(rec.status).to.eq(1);
      const assetAfterSupply = await poolHelpers.assetInPool(poolId, sdk, asset.underlyingSymbol, bob.address);
      expect(parseFloat(utils.formatUnits(assetAfterSupply.supplyBalance, 18))).to.closeTo(
        parseFloat(amounts[idx]),
        0.00000001
      );
    }
  });
});
