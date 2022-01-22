// pool utilities used across downstream tests
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signers";
import { ethers } from "hardhat";
import { cERC20Conf, Fuse } from "../../lib/esm/src";
import { constants, providers, utils } from "ethers";
import { FusePoolData, USDPricedFuseAsset } from "../../lib/esm/src/Fuse/types";

interface PoolCreationParams {
  closeFactor?: number;
  liquidationIncentive?: number;
  poolName: string;
  enforceWhitelist?: boolean;
  whitelist?: Array<string>;
  priceOracleAddress?: string | null;
  signer?: SignerWithAddress | null;
}

export async function createPool({
  closeFactor = 50,
  liquidationIncentive = 8,
  poolName = "TEST",
  enforceWhitelist = false,
  whitelist = [],
  priceOracleAddress = null,
  signer = null,
}: PoolCreationParams): Promise<[string, string, string]> {
  if (!signer) {
    const { bob } = await ethers.getNamedSigners();
    signer = bob;
  }
  if (!priceOracleAddress) {
    const spoFactory = await ethers.getContractFactory("MockPriceOracle", signer);
    const spo = await spoFactory.deploy([10]);
    priceOracleAddress = spo.address;
  }
  if (enforceWhitelist && whitelist.length === 0) {
    throw "If enforcing whitelist, a whitelist array of addresses must be provided";
  }
  const sdk = new Fuse(ethers.provider, "1337");

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
  if (!signer) {
    const { bob } = await ethers.getNamedSigners();
    signer = bob;
  }
  const sdk = new Fuse(ethers.provider, "1337");

  const deployed: DeployedAsset[] = [];
  for (const assetConf of assets) {
    const [assetAddress, implementationAddress, interestRateModel, receipt] = await sdk.deployAsset(
      Fuse.JumpRateModelConf,
      assetConf,
      { from: signer.address }
    );
    if (receipt.status !== 1) {
      throw `Failed to deploy asset: ${receipt.logs}`;
    }
    console.log("deployed asset: ", assetConf.name);
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
  const { bob } = await ethers.getNamedSigners();
  if (!interestRateModelAddress) {
    const jrm = await ethers.getContract("JumpRateModel", bob);
    interestRateModelAddress = jrm.address;
  }
  return await poolAssets(interestRateModelAddress, comptroller, bob);
}

export const poolAssets = async (
  interestRateModelAddress: string,
  comptroller: string,
  signer: SignerWithAddress
): Promise<{ shortName: string; longName: string; assetSymbolPrefix: string; assets: cERC20Conf[] }> => {
  const ethConf: cERC20Conf = {
    underlying: "0x0000000000000000000000000000000000000000",
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Ethereum",
    symbol: "ETH",
    decimals: 8,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 20,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };
  const rgtConf: cERC20Conf = {
    underlying: await ethers.getContract("TRIBEToken", signer).then((c) => c.address),
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "TRIBE Governance Token",
    symbol: "TRIBE",
    decimals: 18,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 15,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };
  const aaveConf: cERC20Conf = {
    underlying: await ethers.getContract("TOUCHToken", signer).then((c) => c.address),
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

  return {
    shortName: "Fuse R1",
    longName: "Rari DAO Fuse Pool R1 (Base)",
    assetSymbolPrefix: "fr1",
    assets: [ethConf, aaveConf, rgtConf],
  };
};

export const ethAssetInPool = async (
  poolId: string,
  sdk: Fuse,
  signer: SignerWithAddress
): Promise<USDPricedFuseAsset> => {
  const fetchedAssetsInPoolAfterBorrow: FusePoolData = await sdk.fetchFusePoolData(poolId, signer.address);
  return fetchedAssetsInPoolAfterBorrow.assets.filter((a) => a.underlyingToken === constants.AddressZero)[0];
};

export const getPoolIndex = async (poolAddress: string, creatorAddress: string, sdk: Fuse) => {
  const [indexes, publicPools] = await sdk.contracts.FusePoolLens.callStatic.getPoolsByAccountWithData(creatorAddress);
  for (let j = 0; j < publicPools.length; j++) {
    if (publicPools[j].comptroller === poolAddress) {
      return indexes[j];
    }
  }
  return null;
};
