// pool utilities used across downstream tests
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { providers, utils } from "ethers";
import { ethers } from "hardhat";

import { cERC20Conf, Fuse, FusePoolData, SupportedChains, USDPricedFuseAsset } from "../../lib/esm/src";
import { bscAssets } from "../../chainDeploy";

interface PoolCreationParams {
  closeFactor?: number;
  liquidationIncentive?: number;
  poolName?: string;
  enforceWhitelist?: boolean;
  whitelist?: Array<string>;
  priceOracleAddress?: string | null;
  signer?: SignerWithAddress | null;
}

export async function createPool({
  closeFactor = 50,
  liquidationIncentive = 8,
  poolName = `TEST - ${Math.random()}`,
  enforceWhitelist = false,
  whitelist = [],
  priceOracleAddress = null,
  signer = null,
}: PoolCreationParams): Promise<[string, string, string]> {
  const { chainId } = await ethers.provider.getNetwork();
  if (!signer) {
    const { bob } = await ethers.getNamedSigners();
    signer = bob;
  }
  if (!priceOracleAddress) {
    const spo = await ethers.getContract("MasterPriceOracle", signer);
    priceOracleAddress = spo.address;
  }
  if (enforceWhitelist && whitelist.length === 0) {
    throw "If enforcing whitelist, a whitelist array of addresses must be provided";
  }
  console.log('chainId: ', chainId);
  const sdk = new Fuse(ethers.provider, chainId);

  // 50% -> 0.5 * 1e18
  const bigCloseFactor = utils.parseEther((closeFactor / 100).toString());
  // 8% -> 1.08 * 1e8
  const bigLiquidationIncentive = utils.parseEther((liquidationIncentive / 100 + 1).toString());

  return await sdk.deployPool(
    poolName,
    enforceWhitelist,
    bigCloseFactor,
    bigLiquidationIncentive,
    priceOracleAddress,
    {},
    { from: signer.address },
    whitelist
  );
}

export type DeployedAsset = {
  symbol: string;
  underlying: string;
  assetAddress: string;
  implementationAddress: string;
  interestRateModel: string;
  receipt: providers.TransactionReceipt;
};
export async function deployAssets(assets: cERC20Conf[], signer?: SignerWithAddress): Promise<DeployedAsset[]> {
  const { chainId } = await ethers.provider.getNetwork();
  if (!signer) {
    const { bob } = await ethers.getNamedSigners();
    signer = bob;
  }
  const sdk = new Fuse(ethers.provider, chainId);

  const deployed: DeployedAsset[] = [];
  for (const assetConf of assets) {
    console.log("deploying asset: ", assetConf);
    const [assetAddress, implementationAddress, interestRateModel, receipt] = await sdk.deployAsset(
      sdk.JumpRateModelConf,
      assetConf,
      { from: signer.address }
    );
    if (receipt.status !== 1) {
      throw `Failed to deploy asset: ${receipt.logs}`;
    }
    console.log("deployed asset: ", assetConf.name, assetAddress);
    console.log("-----------------");
    deployed.push({
      symbol: assetConf.symbol,
      underlying: assetConf.underlying,
      assetAddress,
      implementationAddress,
      interestRateModel,
      receipt,
    });
  }

  return deployed;
}

export async function getAssetsConf(
  comptroller: string,
  interestRateModelAddress?: string
): Promise<{ shortName: string; longName: string; assetSymbolPrefix: string; assets: cERC20Conf[] }> {
  if (!interestRateModelAddress) {
    const jrm = await ethers.getContract("JumpRateModel");
    interestRateModelAddress = jrm.address;
  }
  return await poolAssets(interestRateModelAddress, comptroller);
}

export const poolAssets = async (
  interestRateModelAddress: string,
  comptroller: string,
): Promise<{ shortName: string; longName: string; assetSymbolPrefix: string; assets: cERC20Conf[] }> => {
  const { chainId } = await ethers.provider.getNetwork();
  const ethConf: cERC20Conf = {
    underlying: "0x0000000000000000000000000000000000000000",
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Ethereum",
    symbol: "ETH",
    decimals: 18,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 20,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };

  let assets = [ethConf];

  if (chainId === 31337 || chainId === 1337) {
    const tribeConf: cERC20Conf = {
      underlying: await ethers.getContract("TRIBEToken").then((c) => c.address),
      comptroller,
      interestRateModel: interestRateModelAddress,
      name: "TRIBE Token",
      symbol: "TRIBE",
      decimals: 18,
      admin: "true",
      collateralFactor: 75,
      reserveFactor: 15,
      adminFee: 0,
      bypassPriceFeedCheck: true,
    };
    const touchConf: cERC20Conf = {
      underlying: await ethers.getContract("TOUCHToken").then((c) => c.address),
      comptroller,
      interestRateModel: interestRateModelAddress,
      name: "Midas TOUCH Token",
      symbol: "TOUCH",
      decimals: 18,
      admin: "true",
      collateralFactor: 65,
      reserveFactor: 20,
      adminFee: 0,
      bypassPriceFeedCheck: true,
    };
    assets = assets.concat([tribeConf, touchConf]);
  } else if (chainId === 56) {
    // bsc
    ethConf.name = "Binance Token";
    ethConf.symbol = "BNB";
    const busd = bscAssets.find((b) => b.symbol === "BUSD");
    const busdConfig: cERC20Conf = {
      underlying: busd.underlying,
      comptroller,
      interestRateModel: interestRateModelAddress,
      name: busd.name,
      symbol: busd.symbol,
      decimals: busd.decimals,
      admin: "true",
      collateralFactor: 75,
      reserveFactor: 15,
      adminFee: 0,
      bypassPriceFeedCheck: true,
    };
    assets = assets.concat([busdConfig]);
  }

  return {
    shortName: "Fuse R1",
    longName: "Rari DAO Fuse Pool R1 (Base)",
    assetSymbolPrefix: "fr1",
    assets,
  };
};

export const assetInPool = async (
  poolId: string,
  sdk: Fuse,
  underlyingSymbol: string,
  address?: string
): Promise<USDPricedFuseAsset> => {
  const fetchedAssetsInPool: FusePoolData = await sdk.fetchFusePoolData(poolId, address);
  return fetchedAssetsInPool.assets.filter((a) => a.underlyingSymbol === underlyingSymbol)[0];
};

export const getPoolIndex = async (poolAddress: string, sdk: Fuse) => {
  const [indexes, publicPools] = await sdk.contracts.FusePoolLens.callStatic.getPublicPoolsWithData();
  for (let j = 0; j < publicPools.length; j++) {
    if (publicPools[j].comptroller === poolAddress) {
      return indexes[j];
    }
  }
  return null;
};

export const getPoolByName = async (name: string, sdk: Fuse, address?: string): Promise<FusePoolData> => {
  const [indexes, publicPools] = await sdk.contracts.FusePoolLens.callStatic.getPublicPoolsWithData();
  for (let j = 0; j < publicPools.length; j++) {
    if (publicPools[j].name === name) {
      const poolIndex = await getPoolIndex(publicPools[j].comptroller, sdk);
      return sdk.fetchFusePoolData(poolIndex, address);
    }
  }
  return null;
};

export const logPoolData = async (poolAddress, sdk) => {
  const poolIndex = await getPoolIndex(poolAddress, sdk);
  const fusePoolData = await sdk.fetchFusePoolData(poolIndex, poolAddress);

  const poolAssets = fusePoolData.assets.map((a) => a.underlyingSymbol).join(", ");
  console.log(`Operating on pool with address ${poolAddress}, name: ${fusePoolData.name}, assets ${poolAssets}`);
};
