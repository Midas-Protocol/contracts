import { deployments, ethers, network } from "hardhat";
import { getContractsConfig } from "./utilities";
import { expect } from "chai";
import { Fuse } from "../lib/esm";

describe("PriceOracle deployment", function () {
  describe("Deploy ChainLinkPriceOracle", async function () {
    it("should deploy the price oracle via sdk", async function () {
      const { alice } = await ethers.getNamedSigners();
      const contractConfig = await getContractsConfig(network.name);
      const sdk = new Fuse(ethers.provider, contractConfig);

      const deployedOracle = await sdk.deployPriceOracle("ChainlinkPriceOracle", {}, { from: alice.address });
      expect(deployedOracle).to.be.ok;
    });
  });
});
