// pool utilities used across downstream tests
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signers";
import { ethers, network } from "hardhat";
import { Fuse, cERC20Conf } from "../../lib/esm";
import { providers, utils } from "ethers";
import { getContractsConfig } from "./config";

export async function createPool(
  closeFactor: number = 50,
  liquidationIncentive: number = 8,
  poolName: string = "TEST",
  enforceWhitelist: boolean = false,
  whitelist: Array<string> | null = null,
  priceOracleAddress: string | null = null,
  signer: SignerWithAddress | null = null
): Promise<[string, string, string]> {
  if (!signer) {
    const { bob } = await ethers.getNamedSigners();
    signer = bob;
  }
  if (!priceOracleAddress) {
    const spoFactory = await ethers.getContractFactory("ChainlinkPriceOracle", signer);
    const spo = await spoFactory.deploy([10]);
    priceOracleAddress = spo.address;
  }
  if (enforceWhitelist && whitelist.length === 0) {
    throw "If enforcing whitelist, a whitelist array of addresses must be provided";
  }
  const contractConfig = await getContractsConfig(network.name);
  const sdk = new Fuse(ethers.provider, contractConfig);

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

export async function deployAssets(assets: cERC20Conf[], signer: SignerWithAddress | null = null) {
  if (!signer) {
    const { bob } = await ethers.getNamedSigners();
    signer = bob;
  }
  const contractConfig = await getContractsConfig(network.name);
  const sdk = new Fuse(ethers.provider, contractConfig);

  for (const assetConf of assets) {
    const [, , , receipt] = await sdk.deployAsset(Fuse.JumpRateModelConf, assetConf, { from: signer.address });
    if (receipt.status !== 1) {
      throw `Failed to deploy asset: ${receipt.logs}`;
    }
    console.log("deployed asset: ", assetConf.name);
    console.log("-----------------");
  }
}

export async function getAssetsConf(comptroller: string, interestRateModelAddress?: string): Promise<cERC20Conf[]> {
  if (!interestRateModelAddress) {
    const { bob } = await ethers.getNamedSigners();
    const jrm = await ethers.getContract("JumpRateModel", bob);
    interestRateModelAddress = jrm.address;
  }
  return poolAssets(interestRateModelAddress, comptroller).assets;
}

export const poolAssets = (
  interestRateModelAddress: string,
  comptroller: string
): { shortName: string; longName: string; assetSymbolPrefix: string; assets: cERC20Conf[] } => {
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
  const daiConf: cERC20Conf = {
    underlying: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Dai",
    symbol: "DAI",
    decimals: 18,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 15,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };
  const rgtConf: cERC20Conf = {
    underlying: "0xD291E7a03283640FDc51b121aC401383A46cC623",
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Rari Governance Token",
    symbol: "RGT",
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
    assets: [ethConf, daiConf, rgtConf],
  };
};
