import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { ERC20 } from "../../typechain";
import Fuse from "../Fuse";
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

    let all = await poolModule.createPool({ signer: fuseDeployer, poolName: "SDK-RewardDistributor" });
    console.log({ all });
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
    console.log({ sdk, poolAddress });

    // Deploy
    const touchRewardsDistributor = await sdk.deployRewardsDistributor(touchToken.address, {
      from: fuseDeployer.address,
    });

    // Fund
    await sdk.fundRewardsDistributor(touchRewardsDistributor.address, 100000, {
      from: fuseDeployer.address,
    });

    // Setup Speed
    // await sdk.set(rewardDistributor.address, 10, { from: fuseDeployer.address });
  });
});
