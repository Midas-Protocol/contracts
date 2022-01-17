import { createPool } from "./utils";
import { deployAssets, getAssetsConf } from "./utils/pool";

describe("Deposit flow tests", function () {
  describe("Deposit flow", async function () {
    it("should deposit asset to pool", async function () {
      const [, implementationAddress] = await createPool();
      const assets = await getAssetsConf(implementationAddress);
      await deployAssets(assets);
    });
  });
});
