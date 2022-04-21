import { parseEther } from "ethers/lib/utils";
import { task, types } from "hardhat/config";

export default task("market:create", "Create Market")
  .addParam(
    "assetConfig",
    "Whole asset config in a comma seperated string (`param1,param2...`)",
    undefined,
    types.string
  )
  .setAction(async (taskArgs, hre) => {
    const [
      poolName,
      creator,
      delegateContractName,
      underlying,
      initialExchangeRate, // Initial exchange rate scaled by 1e18
      collateralFactor,
      reserveFactor,
      adminFee,
      bypassPriceFeedCheck,
      plugin,
      rewardsDistributor,
      rewardToken,
    ] = taskArgs.split(",");

    const signer = await hre.ethers.getNamedSigner(creator);

    // @ts-ignore
    const fuseModule = await import("../test/utils/fuseSdk");
    const sdk = await fuseModule.getOrCreateFuse();

    // @ts-ignore
    const poolModule = await import("../test/utils/pool");
    const pool = await poolModule.getPoolByName(poolName, sdk);

    const underlyingToken = await hre.ethers.getContractAt("ERC20", underlying);
    const underlyingTokenSymol = await underlyingToken.callStatic.symbol();

    const assetConf = {
      delegateContractName: delegateContractName,
      underlying: underlying,
      comptroller: pool.comptroller,
      fuseFeeDistributor: sdk.contracts.FuseFeeDistributor,
      interestRateModel: sdk.JumpRateModelConf.interestRateModel,
      initialExchangeRateMantissa: parseEther(initialExchangeRate),
      name: `${poolName} ${underlyingTokenSymol}`,
      symbol: `m${pool.id}-${underlyingTokenSymol}`,
      decimals: 8, // Fuse and Compound use 8 decimals. Do we also want to do this?
      admin: creator,
      collateralFactor: Number(collateralFactor),
      reserveFactor: Number(reserveFactor),
      adminFee: Number(adminFee),
      bypassPriceFeedCheck: bypassPriceFeedCheck === "true",
      plugin: plugin ? plugin : null,
      rewardsDistributor: rewardsDistributor ? rewardsDistributor : null,
      rewardToken: rewardToken ? rewardToken : null,
    };
    const [assetAddress, implementationAddress, interestRateModel, receipt] = await sdk.deployAsset(
      sdk.JumpRateModelConf,
      assetConf,
      { from: signer.address }
    );
  });
