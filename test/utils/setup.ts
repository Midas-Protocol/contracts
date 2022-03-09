import { deployments, ethers } from "hardhat";
import { assets as bscAssets } from "../../chainDeploy/mainnets/bsc";
import { constants } from "ethers";

export const setUpPriceOraclePrices = deployments.createFixture(async ({ run, getChainId }, options) => {
  const chainId = parseInt(await getChainId());
  if (chainId === 31337 || chainId === 1337) {
    await setupLocalOraclePrices();
  } else if (chainId === 56) {
    await setUpBscOraclePrices();
  }
});

const setupLocalOraclePrices = deployments.createFixture(async ({ run }, options) => {
  await run("oracle:set-price", { token: "ETH", price: "1" });
  await run("oracle:set-price", { token: "TOUCH", price: "0.1" });
  await run("oracle:set-price", { token: "TRIBE", price: "0.2" });
});

const setUpBscOraclePrices = deployments.createFixture(async ({ run }, options) => {
  const { deployer } = await ethers.getNamedSigners();
  const oracle = await ethers.getContract("SimplePriceOracle", deployer);

  for (const asset of bscAssets) {
    await run("oracle:add-tokens", { underlyings: asset.underlying, oracles: oracle.address });
    await run("oracle:set-price", { address: asset.underlying, price: "1" });
  }
  await run("oracle:add-tokens", { underlyings: constants.AddressZero, oracles: oracle.address });
  await run("oracle:set-price", { address: constants.AddressZero, price: "1" });
});
