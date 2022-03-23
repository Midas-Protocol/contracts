import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import Fuse from "../../src/Fuse";
import { CErc20, EIP20Interface } from "../../typechain";
import { setUpPriceOraclePrices, tradeNativeForAsset } from "../utils";
import * as collateralHelpers from "../utils/collateral";
import * as poolHelpers from "../utils/pool";
import * as timeHelpers from "../utils/time";
import { constants } from "ethers";

describe("FlywheelModule", function () {
  let poolAAddress: string;
  let poolBAddress: string;
  let sdk: Fuse;
  let erc20OneCToken: CErc20;
  let erc20TwoCToken: CErc20;

  let erc20OneUnderlying: EIP20Interface;
  let erc20TwoUnderlying: EIP20Interface;

  let chainId: number;

  this.beforeEach(async () => {
    ({ chainId } = await ethers.provider.getNetwork());
    if (chainId === 1337) {
      await deployments.fixture();
    }
    await setUpPriceOraclePrices();
    const { deployer } = await ethers.getNamedSigners();

    sdk = new Fuse(ethers.provider, chainId);

    [poolAAddress] = await poolHelpers.createPool({ signer: deployer, poolName: "PoolA-RewardsDistributor-Test" });
    [poolBAddress] = await poolHelpers.createPool({ signer: deployer, poolName: "PoolB-RewardsDistributor-Test" });

    const assetsA = await poolHelpers.getPoolAssets(poolAAddress, sdk.contracts.FuseFeeDistributor.address);
    const deployedAssetsA = await poolHelpers.deployAssets(assetsA.assets, deployer);
    await poolHelpers.getPoolAssets(poolBAddress, sdk.contracts.FuseFeeDistributor.address);

    const erc20One = assetsA.assets.find((a) => a.underlying !== constants.AddressZero); // find first one
    const erc20Two = assetsA.assets.find(
      (a) => a.underlying !== constants.AddressZero && a.underlying !== erc20One.underlying
    ); // find second one

    const deployedErc20One = deployedAssetsA.find((a) => a.underlying === erc20One.underlying);
    const deployedErc20Two = deployedAssetsA.find((a) => a.underlying === erc20Two.underlying);

    erc20OneCToken = (await ethers.getContractAt("CErc20", deployedErc20One.assetAddress)) as CErc20;
    erc20TwoCToken = (await ethers.getContractAt("CErc20", deployedErc20Two.assetAddress)) as CErc20;

    erc20OneUnderlying = (await ethers.getContractAt("EIP20Interface", erc20One.underlying)) as EIP20Interface;
    erc20TwoUnderlying = (await ethers.getContractAt("EIP20Interface", erc20Two.underlying)) as EIP20Interface;

    if (chainId !== 1337) {
      await tradeNativeForAsset({ account: "alice", token: erc20Two.underlying, amount: "500" });
      await tradeNativeForAsset({ account: "deployer", token: erc20Two.underlying, amount: "500" });
    }
  });

  it.only("1 Pool, 1 Flywheel", async function () {
    const { deployer, alice } = await ethers.getNamedSigners();
    const rewardToken = erc20OneUnderlying;
    const market = erc20OneCToken;
    console.log({ rewardToken: rewardToken.address, market: market.address });

    // 1. Deploy Flywheel Core
    const fwCore = await sdk.deployFlywheelCore(rewardToken.address, {
      from: deployer.address,
    });
    console.log({ fwCore: fwCore.address });

    // 1.1. Enable Market for Flywheel Core
    await sdk.addMarketForRewardsToFlywheelCore(fwCore.address, market.address, { from: deployer.address });

    // 1.2. Add Flywheel Core to Pool
    await sdk.addFlywheelCoreToPool(fwCore.address, poolAAddress, { from: deployer.address });

    // 2. Deploy Flywheel Reward: StaticReward
    const fwStaticRewards = await sdk.deployFlywheelStaticRewards(rewardToken.address, fwCore.address, {
      from: deployer.address,
    });

    // 2.1 Fund Static Rewards
    await rewardToken.transfer(fwStaticRewards.address, ethers.utils.parseUnits("100", 18), { from: deployer.address });

    // 2.2 Set Reward Info on Rewards
    await sdk.setStaticRewardInfo(
      fwStaticRewards.address,
      rewardToken.address,
      {
        rewardsEndTimestamp: 0,
        rewardsPerSecond: ethers.utils.parseUnits("0.1", 18),
      },
      { from: deployer.address }
    );
  });
});
