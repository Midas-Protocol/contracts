import { deployments } from "hardhat";

export const setupTest = deployments.createFixture(
  async ({deployments, getNamedAccounts, ethers}, options) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
  }
);