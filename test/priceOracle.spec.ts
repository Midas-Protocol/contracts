import { ethers } from "hardhat";
import { expect } from "chai";
import { Fuse } from "../lib/esm/src";

describe("PriceOracle deployment", function () {
  describe("Deploy ChainLinkPriceOracle", async function () {
    it("should deploy the price oracle via sdk", async function () {
      const { alice } = await ethers.getNamedSigners();
      const sdk = new Fuse(ethers.provider, "1337");

      const deployedOracle = await sdk.deployPriceOracle("ChainlinkPriceOracleV2", {}, { from: alice.address });
      expect(deployedOracle).to.be.ok;
    });
  });
});
