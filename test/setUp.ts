import { deployments, network } from "hardhat";
import { use } from "chai";
import { solidity } from "ethereum-waffle";
// @ts-ignore
import Fuse, { cERC20Conf } from "midas-sdk";

use(solidity);

export const setUpTest = deployments.createFixture(async ({ deployments, getNamedAccounts, ethers }) => {
  console.log(network);
  await deployments.fixture(); // ensure you start from a fresh deployments
  const { deployer, alice, bob } = await getNamedAccounts();

  const FuseFeeDistributor = await ethers.getContract("FuseFeeDistributor", deployer);
  console.log("FuseFeeDistributor: ", FuseFeeDistributor.address);

  const FusePoolDirectory = await ethers.getContract("FusePoolDirectory", deployer);
  const Comptroller = await ethers.getContract("Comptroller", deployer);

  console.log(`Deployed Addresses:\n 
        - Comptroller: ${Comptroller.address}\n 
        - FusePoolDirectory: ${FusePoolDirectory.address}\n
        - FuseFeeDistributor: ${FuseFeeDistributor.address}\n`);

  const accts = [deployer, alice, bob];
  const isWhitelisted = await Promise.all(accts.map(async (d) => await FusePoolDirectory.deployerWhitelist(d)));
  console.log(
    "Whitelisted addresses: ",
    isWhitelisted.map((v, i) => `${accts[i]}: ${v}`)
  );
});

export const poolAssets = (interestRateModelAddress: string, comptroller: string) => {
  const ethConf: cERC20Conf = {
    underlying: "0x0000000000000000000000000000000000000000",
    comptroller: comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Ethereum",
    symbol: "ETH",
    decimals: 8,
    admin: "true",
    collateralFactor: "0.75",
    reserveFactor: "0.2",
    adminFee: "0",
    bypassPriceFeedCheck: true,
  };
  const daiConf: cERC20Conf = {
    underlying: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    comptroller: comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Dai",
    symbol: "DAI",
    decimals: 18,
    admin: "true",
    collateralFactor: "0.75",
    reserveFactor: "0.15",
    adminFee: "0",
    bypassPriceFeedCheck: true,
  };
  const rgtConf: cERC20Conf = {
    underlying: "0xD291E7a03283640FDc51b121aC401383A46cC623",
    comptroller: comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Rari Governance Token",
    symbol: "RGT",
    decimals: 18,
    admin: "true",
    collateralFactor: "0.65",
    reserveFactor: "0.2",
    adminFee: "0",
    bypassPriceFeedCheck: true,
  };

  return {
    shortName: "Fuse R1",
    longName: "Rari DAO Fuse Pool R1 (Base)",
    assetSymbolPrefix: "fr1",
    assets: [ethConf, daiConf, rgtConf],
  };
};
