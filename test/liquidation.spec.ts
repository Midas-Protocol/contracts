import { BigNumber, constants, providers, utils } from "ethers";
import { ethers } from "hardhat";
import { createPool, deployAssets, setupTest } from "./utils";
import { DeployedAsset, getAssetsConf } from "./utils/pool";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import {
  CErc20,
  CEther,
  Comptroller,
  EIP20Interface,
  FuseSafeLiquidator,
  MasterPriceOracle,
  SimplePriceOracle,
} from "../typechain";
import { expect } from "chai";

describe("#safeLiquidate", () => {
  let tribe: DeployedAsset;
  let touch: DeployedAsset;
  let eth: DeployedAsset;
  let poolAddress: string;
  let simpleOracle: SimplePriceOracle;
  let oracle: MasterPriceOracle;
  let liquidator: FuseSafeLiquidator;
  let ethCToken: CEther;
  let tribeCToken: CErc20;
  let tribeUnderlying: EIP20Interface;
  let touchUnderlying: EIP20Interface;
  let tx: providers.TransactionResponse;

  beforeEach(async () => {
    await setupTest();
    const { bob, deployer, rando } = await ethers.getNamedSigners();
    [poolAddress] = await createPool({});
    const assets = await getAssetsConf(poolAddress);
    const deployedAssets = await deployAssets(assets.assets, bob);

    tribe = deployedAssets.find((a) => a.symbol === "TRIBE");
    touch = deployedAssets.find((a) => a.symbol === "TOUCH");
    eth = deployedAssets.find((a) => a.underlying === constants.AddressZero);

    simpleOracle = (await ethers.getContract("SimplePriceOracle", deployer)) as SimplePriceOracle;
    tx = await simpleOracle.setDirectPrice(tribe.underlying, "421407501053518");
    await tx.wait();

    tx = await simpleOracle.setDirectPrice(touch.underlying, "421407501053518000000000000");
    await tx.wait();

    oracle = (await ethers.getContract("MasterPriceOracle")) as MasterPriceOracle;
    liquidator = (await ethers.getContract("FuseSafeLiquidator", rando)) as FuseSafeLiquidator;
    ethCToken = (await ethers.getContractAt("CEther", eth.assetAddress)) as CEther;
    tribeCToken = (await ethers.getContractAt("CErc20", tribe.assetAddress)) as CErc20;
    touchUnderlying = (await ethers.getContractAt("EIP20Interface", touch.underlying)) as EIP20Interface;
    touchCToken = (await ethers.getContractAt("CErc20", touch.assetAddress)) as CErc20;
    tribeUnderlying = (await ethers.getContractAt("EIP20Interface", tribe.underlying)) as EIP20Interface;
  });

  it("should liquidate an ETH borrow for token collateral", async function () {
    this.timeout(120_000);
    const { alice, bob, rando } = await ethers.getNamedSigners();

    const originalPrice = await oracle.getUnderlyingPrice(tribe.assetAddress);

    await addCollateral(
      poolAddress,
      bob.address,
      "TRIBE",
      utils.formatEther(BigNumber.from(3e14).mul(constants.WeiPerEther.div(originalPrice))),
      true
    );

    // Supply 0.001 ETH from other account
    await addCollateral(poolAddress, alice.address, "ETH", "0.001", false);

    // Borrow 0.0001 ETH using token collateral
    const borrowAmount = "0.0001";
    await borrowCollateral(poolAddress, bob.address, "ETH", borrowAmount);

    // Set price of token collateral to 1/10th of what it was
    tx = await simpleOracle.setDirectPrice(tribe.underlying, BigNumber.from(originalPrice).div(10));
    await tx.wait();

    const repayAmount = utils.parseEther(borrowAmount).div(10);

    const balBefore = await tribeCToken.balanceOf(rando.address);

    tx = await liquidator["safeLiquidate(address,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
      eth.assetAddress,
      tribe.assetAddress,
      0,
      tribe.assetAddress,
      constants.AddressZero,
      [],
      [],
      { value: repayAmount, gasLimit: 10000000, gasPrice: utils.parseUnits("10", "gwei") }
    );
    await tx.wait();

    const balAfter = await tribeCToken.balanceOf(rando.address);
    expect(balAfter).to.be.gt(balBefore);
  });

  // Safe liquidate token borrows
  it("should liquidate a token borrow for ETH collateral", async function() {
    this.timeout(120_000);
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // Supply ETH collateral
    await addCollateral(poolAddress, bob.address, "ETH", "0.0001", true);

    // Supply TRIBE from other account
    await addCollateral(poolAddress, alice.address, "TRIBE", "0.5", true);

    // Borrow TRIBE using ETH as collateral
    const borrowAmount = "0.1";
    await borrowCollateral(poolAddress, bob.address, "TRIBE", borrowAmount);

    const originalPrice = await oracle.getUnderlyingPrice(tribe.assetAddress);

    // Set price of borrowed token to 10x of what it was
    tx = await simpleOracle.setDirectPrice(tribe.underlying, BigNumber.from(originalPrice).mul(10));
    await tx.wait();

    const balBefore = await ethCToken.balanceOf(rando.address);
    const repayAmount = utils.parseEther(borrowAmount).div(100);

    tx = await tribeUnderlying.connect(alice).transfer(rando.address, repayAmount);
    tx = await tribeUnderlying.connect(rando).approve(liquidator.address, constants.MaxUint256);
    await tx.wait();

    tx = await liquidator["safeLiquidate(address,uint256,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
      repayAmount,
      tribe.assetAddress,
      eth.assetAddress,
      0,
      eth.assetAddress,
      constants.AddressZero,
      [],
      []
    );
    await tx.wait();

    const balAfter = await ethCToken.balanceOf(rando.address);
    expect(balAfter).to.be.gt(balBefore);
  });
  
  it("should liquidate a token borrow for token collateral", async function() {
    this.timeout(120_000);
    const { alice, bob, rando } = await ethers.getNamedSigners();

    const originalPrice = await oracle.getUnderlyingPrice(tribe.assetAddress);

    // Supply token collateral
    await addCollateral(
      poolAddress,
      bob.address,
      "TRIBE",
      utils.formatEther(BigNumber.from(1e14).mul(constants.WeiPerEther.div(originalPrice))),
      true
    );

    // Supply TOUCH from other account
    await addCollateral(poolAddress, alice.address, "TOUCH", utils.formatEther(1e6), false);

    // Borrow TOUCH using token collateral
    const borrowAmount = utils.formatEther(1e5);
    await borrowCollateral(poolAddress, bob.address, "TOUCH", borrowAmount);

    // Set price of token collateral to 1/10th of what it was
    tx = await simpleOracle.setDirectPrice(tribe.underlying, BigNumber.from(originalPrice).div(10));
    await tx.wait();

    const repayAmount = utils.parseEther(borrowAmount).div(10);

    const balBefore = await tribeCToken.balanceOf(rando.address);

    tx = await touchUnderlying.connect(alice).transfer(rando.address, repayAmount);
    tx = await touchUnderlying.connect(rando).approve(liquidator.address, constants.MaxUint256);
    await tx.wait();

    tx = await liquidator["safeLiquidate(address,uint256,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
      repayAmount,
      touch.assetAddress,
      tribe.assetAddress,
      0,
      tribe.assetAddress,
      constants.AddressZero,
      [],
      []
    );

    const balAfter = await tribeCToken.balanceOf(rando.address);
    expect(balAfter).to.be.gt(balBefore);
  });
});
