import { deployments, ethers } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
// @ts-ignore
import Fuse from "../sdk/fuse-sdk";

use(solidity);

export const setUpTest = deployments.createFixture(
  async ({ deployments, getNamedAccounts, ethers }) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    const { deployer, alice, bob } = await getNamedAccounts();

    const FuseFeeDistributor = await ethers.getContract(
      "FuseFeeDistributor",
      deployer
    );
    console.log("FuseFeeDistributor: ", FuseFeeDistributor.address);

    const FusePoolDirectory = await ethers.getContract(
      "FusePoolDirectory",
      deployer
    );
    const Comptroller = await ethers.getContract("Comptroller", deployer);

    console.log(`Deployed Addresses:\n 
        - Comptroller: ${Comptroller.address}\n 
        - FusePoolDirectory: ${FusePoolDirectory.address}\n
        - FuseFeeDistributor: ${FuseFeeDistributor.address}\n`);

    const accts = [deployer, alice, bob];
    const isWhitelisted = await Promise.all(
      accts.map(async (d) => await FusePoolDirectory.deployerWhitelist(d))
    );
    console.log(
      "Whitelisted addresses: ",
      isWhitelisted.map((v, i) => `${accts[i]}: ${v}`)
    );
  }
);

export const poolAssets = {
  /*
    var erc20 = new fuse.web3.eth.Contract(erc20Abi, underlying);
    var underlyingName = await erc20.methods.name().call();
    var underlyingSymbol = await erc20.methods.symbol().call();
    */

  shortName: "Fuse R1",
  longName: "Rari DAO Fuse Pool R1 (Base)",
  assetSymbolPrefix: "fr1",
  assets: [
    {
      underlying: "0x0000000000000000000000000000000000000000",
      underlyingSymbol: "ETH",
      underlyingName: "Ethereum",
      collateralFactor: 0.75,
      reserveFactor: 0.2,
      interestRateModel:
        Fuse.PUBLIC_INTEREST_RATE_MODEL_CONTRACT_ADDRESSES
          .HARDHDHAT_JumpRateModel,
    },
    {
      underlying: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
      underlyingSymbol: "DAI",
      underlyingName: "Dai",
      collateralFactor: 0.75,
      reserveFactor: 0.15,
      interestRateModel:
        Fuse.PUBLIC_INTEREST_RATE_MODEL_CONTRACT_ADDRESSES
          .HARDHDHAT_JumpRateModel,
    }, // DAI
    {
      underlying: "0xD291E7a03283640FDc51b121aC401383A46cC623",
      underlyingSymbol: "RGT",
      underlyingName: "Rari Governance Token",
      collateralFactor: 0.45,
      reserveFactor: 0.3,
      interestRateModel:
        Fuse.PUBLIC_INTEREST_RATE_MODEL_CONTRACT_ADDRESSES
          .HARDHDHAT_JumpRateModel,
    }, // RGT
  ],
};
