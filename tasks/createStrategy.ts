import { parseEther } from "ethers/lib/utils";
import { task, types } from "hardhat/config";

// npx hardhat pool:create --name Test --creator deployer --price-oracle "" --close-factor 50 --liquiditation-incentive 8 --enforce-whitelist false --network localhost

task("strategy:create", "Create ERC4626 Strategy")
  .addParam("underlying", "Address of the underlying token", undefined, types.string)
  .addParam("name", "Name of the Token", "deployer", types.string)
  .addParam("symbol", "Symbol of the Token", undefined, types.string)
  .addOptionalParam(
    "otherParams",
    "other params that might be required to construct the strategy",
    undefined,
    types.string
  )
  .setAction(async (taskArgs, hre) => {
    const signer = await hre.ethers.getNamedSigner(taskArgs.creator);

    /*  new AutofarmERC4626(
      testToken,
      "TestVault",
      "TSTV",
      0,
      autoToken,
      IAutofarmV2(address(mockAutofarm)),
      FlywheelCore(address(flywheel))
    );
 */
    /* let dep = await hre.ethers.deploy("FuseFeeDistributor", {
      from: deployer,
      salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
      args: [],
      log: true,
      proxy: {
        proxyContract: "OpenZeppelinTransparentProxy",
      },
    });

    const ffd = await dep.deploy();
    console.log("FuseFeeDistributor: ", ffd.address); */
  });
