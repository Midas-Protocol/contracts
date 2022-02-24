import { deployments } from "hardhat";

export const setupTest = deployments.createFixture(async ({ run, deployments, getNamedAccounts, ethers }, options) => {
  await deployments.fixture(); // ensure you start from a fresh deployments
  await run("set-price", { token: "ETH", price: "1" });
  await run("set-price", { token: "TOUCH", price: "0.1" });
  await run("set-price", { token: "TRIBE", price: "0.2" });
});