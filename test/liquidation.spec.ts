import { BigNumber, constants, providers, utils } from "ethers";
import { deployments, ethers } from "hardhat";
import { createPool, deployAssets, setUpBscOraclePrices } from "./utils";
import { assetInPool, DeployedAsset, getAssetsConf, getPoolIndex } from "./utils/pool";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import { CErc20, CEther, EIP20Interface, FuseSafeLiquidator, MasterPriceOracle, SimplePriceOracle } from "../typechain";
import { expect } from "chai";
import { cERC20Conf, Fuse } from "../lib/esm/src";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { whaleSigner } from "./utils/accounts";

describe("#safeLiquidate", () => {
  let whale: SignerWithAddress;

  let eth: cERC20Conf;
  let erc20One: cERC20Conf;
  let erc20Two: cERC20Conf;

  let deployedEth: DeployedAsset;
  let deployedErc20One: DeployedAsset;
  let deployedErc20Two: DeployedAsset;

  let poolAddress: string;
  let simpleOracle: SimplePriceOracle;
  let oracle: MasterPriceOracle;
  let liquidator: FuseSafeLiquidator;

  let ethCToken: CEther;
  let erc20OneCToken: CErc20;
  let erc20TwoCToken: CErc20;

  let erc20OneUnderlying: EIP20Interface;
  let erc20TwoUnderlying: EIP20Interface;
  let tx: providers.TransactionResponse;

  beforeEach(async () => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    await setUpBscOraclePrices();
    const { bob, deployer, rando } = await ethers.getNamedSigners();

    simpleOracle = (await ethers.getContract("SimplePriceOracle", deployer)) as SimplePriceOracle;
    oracle = (await ethers.getContract("MasterPriceOracle", deployer)) as MasterPriceOracle;

    [poolAddress] = await createPool({});
    const assets = await getAssetsConf(poolAddress);

    erc20One = assets.assets.find((a) => a.underlying !== constants.AddressZero); // find first one
    expect(erc20One.underlying).to.be.ok;
    erc20Two = assets.assets.find(
      (a) => a.underlying !== constants.AddressZero && a.underlying !== erc20One.underlying
    ); // find second one

    expect(erc20Two.underlying).to.be.ok;
    eth = assets.assets.find((a) => a.underlying === constants.AddressZero);

    await oracle.add([eth.underlying, erc20One.underlying, erc20Two.underlying], Array(3).fill(simpleOracle.address));

    tx = await simpleOracle.setDirectPrice(eth.underlying, utils.parseEther("1"));
    await tx.wait();

    tx = await simpleOracle.setDirectPrice(erc20One.underlying, "421407501053518000000000000");
    await tx.wait();

    tx = await simpleOracle.setDirectPrice(erc20Two.underlying, "421407501053518");
    await tx.wait();

    const deployedAssets = await deployAssets(assets.assets, bob);

    deployedEth = deployedAssets.find((a) => a.underlying === constants.AddressZero);
    deployedErc20One = deployedAssets.find((a) => a.underlying === erc20One.underlying);
    deployedErc20Two = deployedAssets.find((a) => a.underlying === erc20Two.underlying);

    liquidator = (await ethers.getContract("FuseSafeLiquidator", rando)) as FuseSafeLiquidator;

    ethCToken = (await ethers.getContractAt("CEther", deployedEth.assetAddress)) as CEther;
    erc20OneCToken = (await ethers.getContractAt("CErc20", deployedErc20One.assetAddress)) as CErc20;
    erc20TwoCToken = (await ethers.getContractAt("CErc20", deployedErc20Two.assetAddress)) as CErc20;

    erc20TwoUnderlying = (await ethers.getContractAt("EIP20Interface", erc20Two.underlying)) as EIP20Interface;
    erc20OneUnderlying = (await ethers.getContractAt("EIP20Interface", erc20One.underlying)) as EIP20Interface;
  });

  it.only("should liquidate a native borrow for token collateral", async function () {
    this.timeout(120_000);
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // either use configured whale acct or bob
    whale = await whaleSigner();
    if (!whale) {
      whale = bob;
    }

    const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);

    await addCollateral(poolAddress, whale, erc20One.symbol, "0.6", true);
    const sdk = new Fuse(ethers.provider, await ethers.provider.getNetwork().then((a) => a.chainId));
    const poolId = await getPoolIndex(poolAddress, sdk);
    console.log(`Added ${erc20One.symbol} collateral`);

    let assetAfterDeposit = await assetInPool(poolId, sdk, erc20One.symbol, whale.address);
    console.log(assetAfterDeposit);

    // Supply 0.001 native from other account
    await addCollateral(poolAddress, alice, eth.symbol, "0.001", false);
    console.log("Added native collateral");
    assetAfterDeposit = await assetInPool(poolId, sdk, eth.symbol, whale.address);
    console.log(assetAfterDeposit);

    // Borrow 0.0001 native using token collateral
    const borrowAmount = "0.0001";
    await borrowCollateral(poolAddress, whale.address, eth.symbol, borrowAmount);

    // Set price of token collateral to 1/10th of what it was
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, BigNumber.from(originalPrice).div(10));
    await tx.wait();

    const repayAmount = utils.parseEther(borrowAmount).div(10);

    const balBefore = await erc20OneCToken.balanceOf(rando.address);

    tx = await liquidator["safeLiquidate(address,address,address,uint256,address,address,address[],bytes[])"](
      whale.address,
      deployedEth.assetAddress,
      deployedErc20One.assetAddress,
      0,
      deployedErc20One.assetAddress,
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
  it("should liquidate a token borrow for BNB collateral", async function () {
    this.timeout(120_000);
    const { alice, bob, rando } = await ethers.getNamedSigners();
    const { chainId } = await ethers.provider.getNetwork();

    // Supply BNB collateral
    await addCollateral(poolAddress, bob, eth.symbol, "0.0001", true);

    // Supply BTCB from other account
    await addCollateral(poolAddress, alice, erc20One.symbol, "0.5", true);

    // Borrow BTCB using BNB as collateral
    const borrowAmount = "0.1";
    await borrowCollateral(poolAddress, bob.address, erc20One.symbol, borrowAmount);

    const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);

    // Set price of borrowed token to 10x of what it was
    tx = await simpleOracle.setDirectPrice(deployedErc20One.underlying, BigNumber.from(originalPrice).mul(10));
    await tx.wait();

    const balBefore = await ethCToken.balanceOf(rando.address);
    const repayAmount = utils.parseEther(borrowAmount).div(100);

    tx = await erc20OneUnderlying.connect(alice).transfer(rando.address, repayAmount);
    tx = await erc20OneUnderlying.connect(rando).approve(liquidator.address, constants.MaxUint256);
    await tx.wait();

    tx = await liquidator["safeLiquidate(address,uint256,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
      repayAmount,
      deployedErc20One.assetAddress,
      deployedEth.assetAddress,
      0,
      deployedEth.assetAddress,
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

    const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);

    // Supply token collateral
    await addCollateral(
      poolAddress,
      bob,
      erc20One.symbol,
      utils.formatEther(BigNumber.from(1e14).mul(constants.WeiPerEther.div(originalPrice))),
      true
    );

    // Supply BUSD from other account
    await addCollateral(poolAddress, alice, erc20Two.symbol, utils.formatEther(1e6), false);

    // Borrow BUSD using token collateral
    const borrowAmount = utils.formatEther(1e5);
    await borrowCollateral(poolAddress, bob.address, erc20Two.symbol, borrowAmount);

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
      deployedErc20Two.assetAddress,
      deployedErc20One.assetAddress,
      0,
      deployedErc20One.assetAddress,
      constants.AddressZero,
      [],
      []
    );

    const balAfter = await erc20OneCToken.balanceOf(rando.address);
    expect(balAfter).to.be.gt(balBefore);
  });
});
