import { BigNumber, constants, providers, utils } from "ethers";
import { deployments, ethers } from "hardhat";
import { createPool, deployAssets } from "./utils";
import { DeployedAsset, getAssetsConf } from "./utils/pool";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import { CErc20, CEther, EIP20Interface, FuseSafeLiquidator, MasterPriceOracle, SimplePriceOracle } from "../typechain";
import { expect } from "chai";

describe("#safeLiquidate", () => {
  let erc20One: DeployedAsset;
  let erc20Two: DeployedAsset;
  let eth: DeployedAsset;
  let poolAddress: string;
  let simpleOracle: SimplePriceOracle;
  let oracle: MasterPriceOracle;
  let liquidator: FuseSafeLiquidator;
  let ethCToken: CEther;
  let erc20OneCToken: CErc20;
  let erc20OneUnderlying: EIP20Interface;
  let erc20TwoUnderlying: EIP20Interface;
  let tx: providers.TransactionResponse;

  beforeEach(async () => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    const { bob, deployer, rando } = await ethers.getNamedSigners();
    [poolAddress] = await createPool({});
    const { chainId } = await ethers.provider.getNetwork();
    const assets = await getAssetsConf(poolAddress);
    const deployedAssets = await deployAssets(assets.assets, bob);

    erc20One = deployedAssets.find((a) => a.underlying !== constants.AddressZero); // find first one
    expect(erc20One.underlying).to.be.ok;
    erc20Two = deployedAssets.find(
      (a) => a.underlying !== constants.AddressZero && a.underlying !== erc20One.underlying
    ); // find second one
    expect(erc20Two.underlying).to.be.ok;
    eth = deployedAssets.find((a) => a.underlying === constants.AddressZero);

    oracle = (await ethers.getContract("MasterPriceOracle")) as MasterPriceOracle;
    simpleOracle = (await ethers.getContract("SimplePriceOracle", deployer)) as SimplePriceOracle;
    await oracle.add([erc20One.underlying, erc20Two.underlying], [simpleOracle.address, simpleOracle.address]);

    tx = await simpleOracle.setDirectPrice(erc20One.underlying, "421407501053518");
    await tx.wait();

    tx = await simpleOracle.setDirectPrice(erc20Two.underlying, "421407501053518000000000000");
    await tx.wait();

    liquidator = (await ethers.getContract("FuseSafeLiquidator", rando)) as FuseSafeLiquidator;
    ethCToken = (await ethers.getContractAt("CEther", eth.assetAddress)) as CEther;
    erc20OneCToken = (await ethers.getContractAt("CErc20", erc20One.assetAddress)) as CErc20;
    erc20TwoUnderlying = (await ethers.getContractAt("EIP20Interface", erc20Two.underlying)) as EIP20Interface;
    erc20OneUnderlying = (await ethers.getContractAt("EIP20Interface", erc20One.underlying)) as EIP20Interface;
  });

  it.only("should liquidate an ETH borrow for token collateral", async function () {
    this.timeout(120_000);
    const { alice, bob, rando } = await ethers.getNamedSigners();
    const { chainId } = await ethers.provider.getNetwork();

    const originalPrice = await oracle.getUnderlyingPrice(erc20One.assetAddress);

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
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, BigNumber.from(originalPrice).div(10));
    await tx.wait();

    const repayAmount = utils.parseEther(borrowAmount).div(10);

    const balBefore = await erc20OneCToken.balanceOf(rando.address);

    tx = await liquidator["safeLiquidate(address,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
      eth.assetAddress,
      erc20One.assetAddress,
      0,
      erc20One.assetAddress,
      constants.AddressZero,
      [],
      [],
      { value: repayAmount, gasLimit: 10000000, gasPrice: utils.parseUnits("10", "gwei") }
    );
    await tx.wait();

    const balAfter = await erc20OneCToken.balanceOf(rando.address);
    expect(balAfter).to.be.gt(balBefore);
  });

  // Safe liquidate token borrows
  it("should liquidate a token borrow for ETH collateral", async function () {
    this.timeout(120_000);
    const { alice, bob, rando } = await ethers.getNamedSigners();
    const { chainId } = await ethers.provider.getNetwork();

    // Supply ETH collateral
    await addCollateral(poolAddress, bob.address, "ETH", "0.0001", true);

    // Supply TRIBE from other account
    await addCollateral(poolAddress, alice.address, "TRIBE", "0.5", true);

    // Borrow TRIBE using ETH as collateral
    const borrowAmount = "0.1";
    await borrowCollateral(poolAddress, bob.address, "TRIBE", borrowAmount);

    const originalPrice = await oracle.getUnderlyingPrice(erc20One.assetAddress);

    // Set price of borrowed token to 10x of what it was
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, BigNumber.from(originalPrice).mul(10));
    await tx.wait();

    const balBefore = await ethCToken.balanceOf(rando.address);
    const repayAmount = utils.parseEther(borrowAmount).div(100);

    tx = await erc20OneUnderlying.connect(alice).transfer(rando.address, repayAmount);
    tx = await erc20OneUnderlying.connect(rando).approve(liquidator.address, constants.MaxUint256);
    await tx.wait();

    tx = await liquidator["safeLiquidate(address,uint256,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
      repayAmount,
      erc20One.assetAddress,
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

  it("should liquidate a token borrow for token collateral", async function () {
    this.timeout(120_000);
    const { alice, bob, rando } = await ethers.getNamedSigners();
    const { chainId } = await ethers.provider.getNetwork();

    const originalPrice = await oracle.getUnderlyingPrice(erc20One.assetAddress);

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
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, BigNumber.from(originalPrice).div(10));
    await tx.wait();

    const repayAmount = utils.parseEther(borrowAmount).div(10);

    const balBefore = await erc20OneCToken.balanceOf(rando.address);

    tx = await erc20TwoUnderlying.connect(alice).transfer(rando.address, repayAmount);
    tx = await erc20TwoUnderlying.connect(rando).approve(liquidator.address, constants.MaxUint256);
    await tx.wait();

    tx = await liquidator["safeLiquidate(address,uint256,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
      repayAmount,
      erc20Two.assetAddress,
      erc20One.assetAddress,
      0,
      erc20One.assetAddress,
      constants.AddressZero,
      [],
      []
    );

    const balAfter = await erc20OneCToken.balanceOf(rando.address);
    expect(balAfter).to.be.gt(balBefore);
  });
});
