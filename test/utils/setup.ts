import { deployments } from "hardhat";
import { assets as bscAssets } from "../../chainDeploy/bsc";

export const setupLocalOraclePrices = deployments.createFixture(async ({ run, deployments }, options) => {
  await deployments.fixture(); // ensure you start from a fresh deployments
  await run("set-price", { token: "ETH", price: "1" });
  await run("set-price", { token: "TOUCH", price: "0.1" });
  await run("set-price", { token: "TRIBE", price: "0.2" });
});

export const setUpBscOraclePrices = deployments.createFixture(async ({ run, deployments }, options) => {
  for (const asset of bscAssets) {
    await run("set-price", { address: asset.underlying, price: "1" });
  }
});
