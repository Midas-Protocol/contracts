import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { ERC20 } from "../../typechain";
import Fuse from "../../src/Fuse";
import { setUpPriceOraclePrices } from "../utils";
import * as poolHelpers from "../utils/pool";
import * as collateralHelpers from "../utils/collateral";
import * as timeHelpers from "../utils/time";

describe.only("RewardsDistributor", function () {
  let poolAddress: string;
  let sdk: Fuse;
  let fuseUserA: SignerWithAddress;
  let fuseUserB: SignerWithAddress;
  let fuseDeployer: SignerWithAddress;
  let touchToken: ERC20;
  let cTouchToken: ERC20;

  this.beforeEach(async () => {
    const { chainId } = await ethers.provider.getNetwork();

    const { deployer, alice, bob } = await ethers.getNamedSigners();
    fuseUserA = alice;
    fuseUserB = bob;
    fuseDeployer = deployer;

    sdk = new Fuse(ethers.provider, chainId);

    if (chainId === 1337) {
      await deployments.fixture();
    }
    await setUpPriceOraclePrices();

    [poolAddress] = await poolHelpers.createPool({ signer: fuseDeployer, poolName: "SDK-RewardDistributor" });

    const assets = await poolHelpers.getPoolAssets(poolAddress, sdk.contracts.FuseFeeDistributor.address);
    const deployedAssets = await poolHelpers.deployAssets(assets.assets, deployer);

    // Make sure we have some TOUCH tokens
    touchToken = await ethers.getContract("TOUCHToken", deployer);
    expect(touchToken.balanceOf(fuseDeployer.address)).to.not.eq(0);
    expect(touchToken.balanceOf(fuseUserA.address)).to.not.eq(0);
    expect(touchToken.balanceOf(fuseUserB.address)).to.not.eq(0);

    // sdk.getPoolAssets();
    let cTouchTokenAddress = deployedAssets.find((a) => a.underlying === touchToken.address).assetAddress;
    expect(cTouchTokenAddress).to.be.ok;
    cTouchToken = new ethers.Contract(cTouchTokenAddress, sdk.artifacts.ERC20.abi, deployer) as ERC20;
  });

  it("deployRewardsDistributor", async function () {
    // Deploy
    const touchRewardsDistributor = await sdk.deployRewardsDistributor(touchToken.address, {
      from: fuseDeployer.address,
    });

    // Add to Pool
    await sdk.addRewardsDistributorToPool(touchRewardsDistributor.address, poolAddress, { from: fuseDeployer.address });

    // Fund
    const fundingAmount = ethers.utils.parseUnits("100", 18);
    await sdk.fundRewardsDistributor(touchRewardsDistributor.address, fundingAmount, {
      from: fuseDeployer.address,
    });

    // Setup Supply Side Speed
    const supplySpeed = ethers.utils.parseUnits("1", 0);
    await sdk.updateRewardsDistributorSupplySpeed(touchRewardsDistributor.address, cTouchToken.address, supplySpeed, {
      from: fuseDeployer.address,
    });

    // Setup Borrow Side Speed
    const borrowSpeed = ethers.utils.parseUnits("1", 0);
    await sdk.updateRewardsDistributorBorrowSpeed(touchRewardsDistributor.address, cTouchToken.address, borrowSpeed, {
      from: fuseDeployer.address,
    });

    // Enter Market to start earning rewards
    await collateralHelpers.addCollateral(poolAddress, fuseUserA, "TOUCH", "100", true);
    let blockEarningFrom = await ethers.provider.getBlockNumber();

    // Get Accrued Reward Tokens for Supplier
    expect(
      await sdk.getRewardsDistributorAccruedAmount(touchRewardsDistributor.address, fuseUserA.address, {
        from: fuseUserA.address,
      })
    ).to.eq(0);

    await collateralHelpers.addCollateral(poolAddress, fuseUserB, "TOUCH", "1", true);
    await collateralHelpers.addCollateral(poolAddress, fuseUserA, "TOUCH", "1", true);

    const currentBlock = await ethers.provider.getBlockNumber();
    const blocksPassed = currentBlock - blockEarningFrom;
    const expectedReward = supplySpeed.mul(blocksPassed);
    console.log({ expectedReward });
    expect(
      await sdk.getRewardsDistributorAccruedAmount(touchRewardsDistributor.address, fuseUserA.address, {
        from: fuseUserA.address,
        blockNumber: currentBlock,
      })
    ).to.eq(expectedReward);
  });
});
