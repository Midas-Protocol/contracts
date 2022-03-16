import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import Fuse from "../../src/Fuse";
import { ERC20 } from "../../typechain";
import { setUpPriceOraclePrices } from "../utils";
import * as collateralHelpers from "../utils/collateral";
import * as poolHelpers from "../utils/pool";
import { advanceBlocks } from "../utils/time";

describe("RewardsDistributorModule", function () {
  let poolAAddress: string;
  let poolBAddress: string;
  let sdk: Fuse;
  let fuseUserA: SignerWithAddress;
  let fuseUserB: SignerWithAddress;
  let fuseDeployer: SignerWithAddress;
  let touchToken: ERC20;
  let cTouchToken: ERC20;
  let tribeToken: ERC20;
  let cTribeToken: ERC20;

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

    [poolAAddress] = await poolHelpers.createPool({ signer: fuseDeployer, poolName: "PoolA-RewardsDistributor-Test" });
    [poolBAddress] = await poolHelpers.createPool({ signer: fuseDeployer, poolName: "PoolB-RewardsDistributor-Test" });

    const assetsA = await poolHelpers.getPoolAssets(poolAAddress, sdk.contracts.FuseFeeDistributor.address);
    const deployedAssetsA = await poolHelpers.deployAssets(assetsA.assets, deployer);

    const assetsB = await poolHelpers.getPoolAssets(poolBAddress, sdk.contracts.FuseFeeDistributor.address);
    const deployedAssetsB = await poolHelpers.deployAssets(assetsB.assets, deployer);

    // Make sure we have some TOUCH tokens
    touchToken = await ethers.getContract("TOUCHToken", deployer);
    expect(touchToken.balanceOf(fuseDeployer.address)).to.not.eq(0);
    expect(touchToken.balanceOf(fuseUserA.address)).to.not.eq(0);
    expect(touchToken.balanceOf(fuseUserB.address)).to.not.eq(0);

    let cTouchTokenAddress = deployedAssetsA.find((a) => a.underlying === touchToken.address)?.assetAddress;
    let cTouchTokenAddressB = deployedAssetsA.find((a) => a.underlying === touchToken.address)?.assetAddress;
    expect(cTouchTokenAddress).to.be.ok;
    cTouchToken = new ethers.Contract(cTouchTokenAddress, sdk.artifacts.ERC20.abi, deployer) as ERC20;

    // Make sure we have some TRIBE tokens
    tribeToken = await ethers.getContract("TRIBEToken", deployer);
    expect(tribeToken.balanceOf(fuseDeployer.address)).to.not.eq(0);
    expect(tribeToken.balanceOf(fuseUserA.address)).to.not.eq(0);
    expect(tribeToken.balanceOf(fuseUserB.address)).to.not.eq(0);

    let cTribeTokenAddress = deployedAssetsA.find((a) => a.underlying === tribeToken.address)?.assetAddress;
    expect(cTribeTokenAddress).to.be.ok;
    cTribeToken = new ethers.Contract(cTribeTokenAddress, sdk.artifacts.ERC20.abi, deployer) as ERC20;
  });

  it("1 Pool, 1 Reward Distributor", async function () {
    // Deploy RewardsDistributors
    const touchRewardsDistributor = await sdk.deployRewardsDistributor(touchToken.address, {
      from: fuseDeployer.address,
    });

    // Fund RewardsDistributors
    const fundingAmount = ethers.utils.parseUnits("100", 18);
    await sdk.fundRewardsDistributor(touchRewardsDistributor.address, fundingAmount, {
      from: fuseDeployer.address,
    });

    // Add RewardsDistributor to Pool
    await sdk.addRewardsDistributorToPool(touchRewardsDistributor.address, poolAAddress, {
      from: fuseDeployer.address,
    });

    // Setup 'TOUCH' Supply Side Speed
    const supplySpeed = ethers.utils.parseUnits("1", 0);
    await sdk.updateRewardsDistributorSupplySpeed(touchRewardsDistributor.address, cTouchToken.address, supplySpeed, {
      from: fuseDeployer.address,
    });

    // Setup 'TOUCH' Borrow Side Speed
    const borrowSpeed = ethers.utils.parseUnits("1", 0);
    await sdk.updateRewardsDistributorBorrowSpeed(touchRewardsDistributor.address, cTouchToken.address, borrowSpeed, {
      from: fuseDeployer.address,
    });

    // Check if MarketRewards are correctly returned
    const marketRewards = await sdk.getMarketRewardsByPool(poolAAddress, { from: fuseUserA.address });
    const touchMarketRewards = marketRewards.find((mr) => mr.cToken === cTouchToken.address);
    expect(touchMarketRewards).to.be.ok;

    const supplyRewardsTouch = touchMarketRewards.supplyRewards.find(
      (br) => br.distributor === touchRewardsDistributor.address
    );
    expect(supplyRewardsTouch).to.be.ok;
    expect(supplyRewardsTouch.speed).to.eq(supplySpeed);

    const borrowRewardsTouch = touchMarketRewards.borrowRewards.find(
      (br) => br.distributor === touchRewardsDistributor.address
    );
    expect(borrowRewardsTouch).to.be.ok;
    expect(supplyRewardsTouch.speed).to.eq(borrowSpeed);

    // Check if ClaimableRewards are correctly returned => no rewards yet
    const claimableRewardsBefore = await sdk.getRewardDistributorClaimableRewards(fuseUserA.address, {
      from: fuseUserA.address,
    });
    expect(claimableRewardsBefore.length).to.eq(0);

    // Enter Rewarded Market, Single User so 100% Rewards from RewardDistributor
    await collateralHelpers.addCollateral(poolAAddress, fuseUserA, "TOUCH", "100", true);

    // Advance Blocks
    const blocksToAdvance = 250;
    await advanceBlocks(blocksToAdvance);

    // Check if ClaimableRewards are correctly returned
    const claimableRewardsAfter250 = await sdk.getRewardDistributorClaimableRewards(fuseUserA.address, {
      from: fuseUserA.address,
    });
    expect(claimableRewardsAfter250[0].amount).to.eq(supplySpeed.mul(blocksToAdvance));

    // Claim Rewards
    await sdk.claimAllRewardDistributorRewards(touchRewardsDistributor.address, { from: fuseUserA.address });
    const claimableRewardsAfterClaim = await sdk.getRewardDistributorClaimableRewards(fuseUserA.address, {
      from: fuseUserA.address,
    });
    expect(claimableRewardsAfterClaim.length).to.eq(0);
  });
});
