import { ethers, waffle, deployments } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
import { Contract } from "@ethersproject/contracts";
import Fuse from "./fuse-sdk/src";

use(solidity);

let comptroller: Contract;
const setupTest = deployments.createFixture(
  async ({ deployments, getNamedAccounts, ethers }) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    const { deployer, alice } = await getNamedAccounts();

    const compFactory = await ethers.getContractFactory("Comptroller", alice);
    comptroller = await compFactory.deploy();

    const FuseFeeDistributor = await ethers.getContract(
      "FuseFeeDistributor",
      deployer
    );
    console.log("FuseFeeDistributor: ", FuseFeeDistributor.address);

    const FusePoolDirectory = await ethers.getContract(
      "FusePoolDirectory",
      deployer
    );
    console.log("alice: ", alice);
    const tx = await FusePoolDirectory.initialize(true, [alice]);
    await tx.wait();
    const isWhitelisted = await FusePoolDirectory.deployerWhitelist(alice);
    console.log("isWhitelisted: ", isWhitelisted);
  }
);

describe("FusePoolDirectory", () => {
  beforeEach(async () => {
    await setupTest();
  });

  it("should deploy the pool", async () => {
    const deployer = await ethers.getNamedSigner("deployer");
    const alice = await ethers.getNamedSigner("alice");
    const priceOracleFactory = await ethers.getContractFactory(
      "SimplePriceOracle",
      deployer
    );
    const priceOracle = await priceOracleFactory.deploy();
    console.log("priceOracle.address: ", priceOracle.address);
    expect(priceOracle.address).to.be.ok;

    const fusePoolDirectory = await ethers.getContract(
      "FusePoolDirectory",
      alice
    );
    console.log("fusePoolDirectory.address: ", fusePoolDirectory.address);
    expect(fusePoolDirectory.address).to.be.ok;

    const deploy = await fusePoolDirectory.functions.deployPool(
      "TEST",
      comptroller.address,
      true,
      "500000000000000000",
      "1100000000000000000",
      priceOracle.address
    );

    console.log("deploy: ", deploy);
  });
});

describe("FuseSDK", () => {
  let sdk;
  beforeEach(async () => {
    await setupTest();
    sdk = new Fuse("http://localhost:8545");
  });
});
