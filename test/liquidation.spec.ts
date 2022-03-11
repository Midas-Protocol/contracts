import { BigNumber, constants, providers, utils } from "ethers";
import { deployments, ethers } from "hardhat";
import { setUpLiquidation } from "./utils";
import { DeployedAsset } from "./utils/pool";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import { CErc20, CEther, EIP20Interface, FuseSafeLiquidator, MasterPriceOracle, SimplePriceOracle } from "../typechain";
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

  let ethCToken: CEther;
  let erc20OneCToken: CErc20;
  let erc20TwoCToken: CErc20;

  let erc20OneUnderlying: EIP20Interface;
  let erc20TwoUnderlying: EIP20Interface;
  let tx: providers.TransactionResponse;

  beforeEach(async () => {
    await deployments.fixture(); // ensure you start from a fresh deployments
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
      simpleOracle,
    } = await setUpLiquidation());
  });

  it("should liquidate a native borrow for token collateral", async function () {
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // either use configured whale acct or bob
    // Supply 0.1 tokenOne from other account
    await addCollateral(poolAddress, bob, erc20One.symbol, "0.1", true);
    console.log(`Added ${erc20One.symbol} collateral`);

    // Supply 1 native from other account
    await addCollateral(poolAddress, alice, eth.symbol, "1", false);

    // Borrow 0.5 native using token collateral
    const borrowAmount = "0.5";
    await borrowCollateral(poolAddress, bob.address, eth.symbol, borrowAmount);

    // Set price of tokenOne collateral to 1/10th of what it was
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, utils.parseEther("1"));
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
  });

  // Safe liquidate token borrows
  it("should liquidate a token borrow for native collateral", async function () {
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // Supply native collateral
    await addCollateral(poolAddress, bob, eth.symbol, "0.1", true);

    // Supply tokenOne from other account
    await addCollateral(poolAddress, alice, erc20One.symbol, "0.01", true);

    // Borrow tokenOne using native as collateral
    const borrowAmount = "0.005";
    await borrowCollateral(poolAddress, bob.address, erc20One.symbol, borrowAmount);

    const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);

    // Set price of borrowed token to 10x of what it was
    tx = await simpleOracle.setDirectPrice(deployedErc20One.underlying, BigNumber.from(originalPrice).mul(10));
    await tx.wait();

    const balBefore = await ethCToken.balanceOf(rando.address);
    const repayAmount = utils.parseEther(borrowAmount).div(15);

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
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // send some tokens from whale to supplier
    tx = await erc20OneUnderlying.connect(alice).transfer(bob.address, utils.parseEther("1"));

    const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);

    // Supply tokenOne collateral
    await addCollateral(poolAddress, bob, erc20One.symbol, "0.5", true);

    // Supply tokenTwo from other account
    await addCollateral(poolAddress, alice, erc20Two.symbol, "10000", false);

    // Borrow tokenTwo using tokenOne collateral
    const borrowAmount = "5000";
    await borrowCollateral(poolAddress, bob.address, erc20Two.symbol, borrowAmount);

    // Set price of tokenOne collateral to 1/10th of what it was
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, BigNumber.from(originalPrice).div(10));
    await tx.wait();

    const repayAmount = utils.parseEther(borrowAmount).div(15);

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
