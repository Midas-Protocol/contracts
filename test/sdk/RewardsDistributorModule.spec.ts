import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { ERC20 } from "../../typechain";
import Fuse from "../../src/Fuse";
import { setUpPriceOraclePrices } from "../utils";
import * as poolModule from "../utils/pool";

describe.only("RewardsDistributor", function () {
  let poolAddress: string;
  let sdk: Fuse;
  let fuseUser: SignerWithAddress;
  let fuseDeployer: SignerWithAddress;
  let touchToken: ERC20;
  let cTouchTokenAddress: string;

  this.beforeEach(async () => {
    const { chainId } = await ethers.provider.getNetwork();

    const { deployer, alice } = await ethers.getNamedSigners();
    fuseUser = alice;
    fuseDeployer = deployer;

    sdk = new Fuse(ethers.provider, chainId);

    if (chainId === 1337) {
      await deployments.fixture();
    }
    await setUpPriceOraclePrices();

    [poolAddress] = await poolModule.createPool({ signer: fuseDeployer, poolName: "SDK-RewardDistributor" });

    await poolModule.createPool({ signer: fuseDeployer, poolName: "SDK-RewardDistributor-2" });

    const assets = await poolModule.getPoolAssets(poolAddress, sdk.contracts.FuseFeeDistributor.address);
    const deployedAssets = await poolModule.deployAssets(assets.assets, deployer);

    // Make sure we have some TOUCH tokens
    touchToken = await ethers.getContract("TOUCHToken", deployer);
    expect(touchToken.balanceOf(fuseDeployer.address)).to.not.eq(0);

    // sdk.getPoolAssets();
    cTouchTokenAddress = deployedAssets.find((a) => a.underlying === touchToken.address).assetAddress;
    expect(cTouchTokenAddress).to.be.ok;
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
    const supplySpeed = ethers.utils.parseUnits("10", 18);
    await sdk.updateRewardsDistributorSupplySpeed(touchRewardsDistributor.address, cTouchTokenAddress, supplySpeed, {
      from: fuseDeployer.address,
    });
    expect(
      await sdk.getRewardsDistributorSupplySpeed(touchRewardsDistributor.address, cTouchTokenAddress, {
        from: fuseDeployer.address,
      })
    ).to.eq(supplySpeed);

    // Setup Borrow Side Speed
    const borrowSpeed = ethers.utils.parseUnits("1", 18);
    await sdk.updateRewardsDistributorBorrowSpeed(touchRewardsDistributor.address, cTouchTokenAddress, borrowSpeed, {
      from: fuseDeployer.address,
    });
    expect(
      await sdk.getRewardsDistributorSupplySpeed(touchRewardsDistributor.address, cTouchTokenAddress, {
        from: fuseDeployer.address,
      })
    ).to.eq(borrowSpeed);
  });
});
