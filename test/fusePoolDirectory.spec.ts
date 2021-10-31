import { ethers, waffle, deployments } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";

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
  beforeEach(async () => {
    await setupTest();
  });

  it("should deploy the pool", async () => {
    const FusePoolDirectory = await deployments.get("FusePoolDirectory");
    expect(FusePoolDirectory.address).to.be.ok;
  });
});
