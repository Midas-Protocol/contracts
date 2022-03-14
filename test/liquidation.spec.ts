import { BigNumber, constants, providers, utils } from "ethers";
import { deployments, ethers } from "hardhat";
import { setUpLiquidation, tradeNativeForAsset } from "./utils";
import { DeployedAsset } from "./utils/pool";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import {
  CErc20,
  CEther,
  EIP20Interface,
  FuseFeeDistributor,
  FuseSafeLiquidator,
  MasterPriceOracle,
  SimplePriceOracle,
} from "../typechain";
import { expect } from "chai";
import { cERC20Conf } from "../dist/esm/src";

describe("#safeLiquidate", () => {
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
  let fuseFeeDistributor: FuseFeeDistributor;

  let ethCToken: CEther;
  let erc20OneCToken: CErc20;
  let erc20TwoCToken: CErc20;

  let erc20OneUnderlying: EIP20Interface;
  let erc20TwoUnderlying: EIP20Interface;
  let tx: providers.TransactionResponse;

  const poolName = "liquidation - no fl";

  beforeEach(async () => {
    const { chainId } = await ethers.provider.getNetwork();
    if (chainId === 1337) {
      await deployments.fixture();
    }
    ({
      poolAddress,
      deployedEth,
      deployedErc20One,
      deployedErc20Two,
      eth,
      erc20One,
      erc20Two,
      ethCToken,
      erc20OneCToken,
      erc20TwoCToken,
      liquidator,
      erc20OneUnderlying,
      erc20TwoUnderlying,
      oracle,
      simpleOracle,
      fuseFeeDistributor,
    } = await setUpLiquidation({ poolName }));
  });

  it("should liquidate a native borrow for token collateral", async function () {
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // get some liquidity via Uniswap
    await tradeNativeForAsset({ account: "bob", token: erc20One.underlying, amount: "300" });

    // either use configured whale acct or bob
    // Supply 0.1 tokenOne from other account
    await addCollateral(poolAddress, bob, erc20One.symbol, "0.1", true);
    console.log(`Added ${erc20One.symbol} collateral`);

    // Supply 1 native from other account
    await addCollateral(poolAddress, alice, eth.symbol, "1", false);

    // Borrow 0.5 native using token collateral
    const borrowAmount = "0.5";
    await borrowCollateral(poolAddress, bob.address, eth.symbol, borrowAmount);

    const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);

    // Set price of tokenOne collateral to 1/10th of what it was
    tx = await simpleOracle.setDirectPrice(deployedErc20One.underlying, BigNumber.from(originalPrice).div(10));
    await tx.wait();

    const repayAmount = utils.parseEther(borrowAmount).div(10);
    const balBefore = await erc20OneCToken.balanceOf(rando.address);

    tx = await liquidator["safeLiquidate(address,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
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

    // return price to what it was
    tx = await simpleOracle.setDirectPrice(deployedErc20One.underlying, originalPrice);
    await tx.wait();
  });

  // Safe liquidate token borrows
  it("should liquidate a token borrow for native collateral", async function () {
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // get some liquidity via Uniswap
    await tradeNativeForAsset({ account: "alice", token: erc20One.underlying, amount: "300" });

    // Supply native collateral
    await addCollateral(poolAddress, bob, eth.symbol, "1", true);
    console.log(`Added ${eth.symbol} collateral`);

    // Supply tokenOne from other account
    await addCollateral(poolAddress, alice, erc20One.symbol, "0.1", true);
    console.log(`Added ${erc20One.symbol} collateral`);

    // Borrow tokenOne using native as collateral
    const borrowAmount = "0.05";
    await borrowCollateral(poolAddress, bob.address, erc20One.symbol, borrowAmount);
    console.log(`Borrowed ${erc20One.symbol} collateral`);

    const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);
    const balBefore = await ethCToken.balanceOf(rando.address);
    const repayAmount = utils.parseEther(borrowAmount).div(15);

    // Set price of borrowed token to 10x of what it was
    tx = await simpleOracle.setDirectPrice(deployedErc20One.underlying, BigNumber.from(originalPrice).mul(10));
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

    // return price to what it was
    tx = await simpleOracle.setDirectPrice(deployedErc20One.underlying, originalPrice);
    await tx.wait();
  });

  it.skip("should liquidate a token borrow for token collateral", async function () {
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // get some liquidity via Uniswap
    await tradeNativeForAsset({ account: "alice", token: erc20One.underlying, amount: "300" });
    await tradeNativeForAsset({ account: "bob", token: erc20Two.underlying, amount: "100" });
    await tradeNativeForAsset({ account: "rando", token: erc20Two.underlying, amount: "100" });

    // // send some tokens from alic to bob
    // tx = await erc20OneUnderlying.connect(alice).transfer(bob.address, utils.parseEther("1"));

    const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);

    // Supply tokenOne collateral
    await addCollateral(poolAddress, alice, erc20One.symbol, "0.5", true);
    console.log(`Added ${erc20One.symbol} collateral`);

    // Supply tokenTwo from other account
    await addCollateral(poolAddress, bob, erc20Two.symbol, "5000", false);
    console.log(`Added ${erc20Two.symbol} collateral`);

    // Borrow tokenTwo using tokenOne collateral
    const borrowAmount = "2500";
    await borrowCollateral(poolAddress, alice.address, erc20Two.symbol, borrowAmount);
    console.log(`Borrowed ${erc20Two.symbol} collateral`);

    const repayAmount = utils.parseEther(borrowAmount).div(15);
    const balBefore = await erc20OneCToken.balanceOf(rando.address);

    // Set price of tokenOne collateral to 1/10th of what it was
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, BigNumber.from(originalPrice).div(10));
    tx = await erc20TwoUnderlying.connect(alice).transfer(rando.address, repayAmount);
    tx = await erc20TwoUnderlying.connect(rando).approve(liquidator.address, constants.MaxUint256);
    tx = await erc20OneUnderlying.connect(rando).approve(liquidator.address, constants.MaxUint256);

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

    // return price to what it was
    tx = await simpleOracle.setDirectPrice(deployedErc20One.underlying, originalPrice);
    await tx.wait();
  });
});
