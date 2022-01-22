import { createPool, setupTest, deployAssets, getAssetsConf } from "./utils";

describe("Deposit flow tests", function () {
  this.beforeEach(async () => {
    await setupTest();
  });

  describe("Deposit flow", async function () {
    it("should deposit asset to pool", async function () {
      this.timeout(120000);
      console.log(111111111);
      const [, implementationAddress] = await createPool();
      console.log(2222222222);
      const assets = await getAssetsConf(implementationAddress);
      console.log(3333333333);
      await deployAssets(assets.assets);
      console.log(4444444444);
    });
  });
});
