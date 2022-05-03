import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import Fuse from "../../src/Fuse";
import { setUpPriceOraclePrices } from "../utils";
import * as poolHelpers from "../utils/pool";
import { BigNumber, constants, providers, utils } from "ethers";
import { chainDeployConfig } from "../../chainDeploy";
import { getOrCreateFuse } from "../utils/fuseSdk";
import { SimplePriceOracle } from "../../typechain/SimplePriceOracle";

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
    console.log(sdk.chainPlugins);

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
  });

  it.only("user can supply", async function () {
    const { deployer } = await ethers.getNamedSigners();
    const poolId = (await poolHelpers.getPoolIndex(poolAddress, sdk)).toString();
    console.log(poolId);
    const assetsInPool = await sdk.fetchFusePoolData(poolId);
    console.log(assetsInPool);
    const asset = assetsInPool.assets.find((asset) => asset.underlyingToken === constants.AddressZero);
    const res = await sdk.supply(
      asset.cToken,
      asset.underlyingToken,
      assetsInPool.comptroller,
      true,
      true,
      utils.parseUnits("3", 18),
      { from: deployer.address }
    );
    tx = res.tx;
    rec = await tx.wait();
    expect(rec.status).to.eq(1);
    const assetAfterSupply = await poolHelpers.assetInPool(
      poolId,
      sdk,
      chainDeployConfig[chainId].config.nativeTokenSymbol,
      deployer.address
    );
    expect(utils.formatUnits(assetAfterSupply.supplyBalance, 18)).to.eq("3.0");
  });

  it("user can borrow", async function () {
    const { deployer } = await ethers.getNamedSigners();
    const poolId = (await poolHelpers.getPoolIndex(poolAddress, sdk)).toString();
    const assetsInPool = await sdk.fetchFusePoolData(poolId);
    const asset = assetsInPool.assets.find((asset) => asset.underlyingToken === constants.AddressZero);
    const res = await sdk.supply(
      asset.cToken,
      asset.underlyingToken,
      assetsInPool.comptroller,
      true,
      true,
      utils.parseUnits("3", 18),
      { from: deployer.address }
    );
    tx = res.tx;
    rec = await tx.wait();
    expect(rec.status).to.eq(1);
    const resp = await sdk.borrow(asset.cToken, utils.parseUnits("2", 18), { from: deployer.address });
    tx = resp.tx;
    rec = await tx.wait();
    expect(rec.status).to.eq(1);
    const assetAfterBorrow = await poolHelpers.assetInPool(
      poolId,
      sdk,
      chainDeployConfig[chainId].config.nativeTokenSymbol,
      deployer.address
    );
    expect(utils.formatUnits(assetAfterBorrow.borrowBalance, 18)).to.eq("2.0");
  });

  it("user can withdraw", async function () {
    const { deployer } = await ethers.getNamedSigners();
    const poolId = (await poolHelpers.getPoolIndex(poolAddress, sdk)).toString();
    const assetsInPool = await sdk.fetchFusePoolData(poolId);
    const asset = assetsInPool.assets.find((asset) => asset.underlyingToken === constants.AddressZero);
    const res = await sdk.supply(
      asset.cToken,
      asset.underlyingToken,
      assetsInPool.comptroller,
      true,
      true,
      utils.parseUnits("3", 18),
      { from: deployer.address }
    );
    tx = res.tx;
    rec = await tx.wait();
    expect(rec.status).to.eq(1);
    const resp = await sdk.withdraw(asset.cToken, utils.parseUnits("2", 18), { from: deployer.address });
    tx = resp.tx;
    rec = await tx.wait();
    expect(rec.status).to.eq(1);
    const assetAfterWithdraw = await poolHelpers.assetInPool(
      poolId,
      sdk,
      chainDeployConfig[chainId].config.nativeTokenSymbol,
      deployer.address
    );
    expect(utils.formatUnits(assetAfterWithdraw.supplyBalance, 18)).to.eq("1.0");
  });

  it("user can repay", async function () {
    const { deployer } = await ethers.getNamedSigners();
    const poolId = (await poolHelpers.getPoolIndex(poolAddress, sdk)).toString();
    const assetsInPool = await sdk.fetchFusePoolData(poolId);
    const asset = assetsInPool.assets.find((asset) => asset.underlyingToken === constants.AddressZero);
    let res = await sdk.supply(
      asset.cToken,
      asset.underlyingToken,
      assetsInPool.comptroller,
      true,
      true,
      utils.parseUnits("5", 18),
      { from: deployer.address }
    );
    tx = res.tx;
    rec = await tx.wait();
    expect(rec.status).to.eq(1);

    res = await sdk.borrow(asset.cToken, utils.parseUnits("3", 18), { from: deployer.address });
    tx = res.tx;
    rec = await tx.wait();
    expect(rec.status).to.eq(1);

    const assetBeforeRepay = await poolHelpers.assetInPool(
      poolId,
      sdk,
      chainDeployConfig[chainId].config.nativeTokenSymbol,
      deployer.address
    );

    res = await sdk.repay(asset.cToken, asset.underlyingToken, true, false, utils.parseUnits("2", 18), {
      from: deployer.address,
    });
    tx = res.tx;
    rec = await tx.wait();
    expect(rec.status).to.eq(1);
    const assetAfterRepay = await poolHelpers.assetInPool(
      poolId,
      sdk,
      chainDeployConfig[chainId].config.nativeTokenSymbol,
      deployer.address
    );
    expect(assetBeforeRepay.borrowBalance.gt(assetAfterRepay.borrowBalance)).to.eq(true);
  });
});
