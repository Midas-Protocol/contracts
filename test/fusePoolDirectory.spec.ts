import { ethers, waffle, deployments } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signers";

use(solidity);

const setupTest = deployments.createFixture(
  async ({ deployments, getNamedAccounts, ethers }) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    const { deployer } = await getNamedAccounts();
    const FusePoolDirectory = await ethers.getContract(
      "FusePoolDirectory",
      deployer
    );
    await FusePoolDirectory.initialize(true, []);
  }
);

describe("FusePoolDirectory", () => {
  let deployer: SignerWithAddress;
  beforeEach(async () => {
    deployer = await ethers.getNamedSigner("deployer");
    await setupTest();
  });

  it("should deploy the pool", async () => {
    const priceOracleFactory = await ethers.getContractFactory(
      "SimplePriceOracle",
      deployer
    );
    const priceOracle = await priceOracleFactory.deploy();
    console.log("priceOracle.address: ", priceOracle.address);
    expect(priceOracle.address).to.be.ok;

    const fusePoolDirectory = await ethers.getContract("FusePoolDirectory");
    console.log("fusePoolDirectory.address: ", fusePoolDirectory.address);
    expect(fusePoolDirectory.address).to.be.ok;

    const comptroller = await ethers.getContract("Comptroller");

    const deploy = await fusePoolDirectory.functions.deployPool(
      "TEST",
      comptroller.address,
      true,
      0,
      0,
      priceOracle.address
    );

    console.log("deploy: ", deploy);
  });
});
