import { ethers, waffle, deployments } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";

describe("FusePoolDirectory", () => {
  beforeEach(async () => {
    await deployments.fixture();
  });

  it("should deploy the pool", async () => {
    const FusePoolDirectory = await deployments.get("FusePoolDirectory");
    expect(FusePoolDirectory.address).to.be.ok;
  });
});
