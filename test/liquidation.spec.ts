import { BigNumber, constants, providers, utils } from "ethers";
import { ethers } from "hardhat";
import { createPool, deployAssets, setupTest } from "./utils";
import { DeployedAsset, getAssetsConf } from "./utils/pool";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import {
  CErc20,
  CEther,
  CToken,
  EIP20Interface,
  FusePoolLensSecondary,
  FuseSafeLiquidator,
  MasterPriceOracle,
  SimplePriceOracle,
} from "../typechain";
import { expect } from "chai";

// async function setupUnhealthyEthBorrowWithTokenCollateral(tokenCollateral) {
//   // Default token collateral to DAI
//   if (tokenCollateral === undefined) tokenCollateral = "0x6b175474e89094c44da98b954eedeac495271d0f";
//   var originalPrice = testAssetFixtures.find(
//     (item) => tokenCollateral.toLowerCase() === item.underlying.toLowerCase()
//   ).price;

//   // Supply token collateral
//   var token = new fuse.web3.eth.Contract(erc20Abi, tokenCollateral);
//   var cToken = new fuse.web3.eth.Contract(cErc20Abi, assetAddresses[tokenCollateral.toLowerCase()]);
//   await token.methods
//     .approve(cToken.options.address, Fuse.Web3.utils.toBN(2).pow(Fuse.Web3.utils.toBN(256)).subn(1))
//     .send({ from: accounts[0],,});
//   await cToken.methods
//     .mint(Fuse.Web3.utils.toBN(3e14).mul(Fuse.Web3.utils.toBN(1e18)).div(Fuse.Web3.utils.toBN(originalPrice)))
//     .send({ from: accounts[0],,});

//   // Supply 0.001 ETH from other account
//   var cToken = new fuse.web3.eth.Contract(cEtherAbi, assetAddresses["0x0000000000000000000000000000000000000000"]);
//   await cToken.methods.mint().send({ from: accounts[1], gas: 5e6,, value: Fuse.Web3.utils.toBN(1e15) });

//   // Borrow 0.0001 ETH using token collateral
//   await comptroller.methods
//     .enterMarkets([assetAddresses[tokenCollateral.toLowerCase()]])
//     .send({ from: accounts[0],,});
//   await cToken.methods.borrow(Fuse.Web3.utils.toBN(1e14)).send({ from: accounts[0],,});

//   // Set price of token collateral to 1/10th of what it was
//   await simplePriceOracle.methods
//     .setDirectPrice(tokenCollateral, Fuse.Web3.utils.toBN(originalPrice).divn(10))
//     .send({ from: accounts[0],,});
// }

describe("#safeLiquidate", () => {
  let tribe: DeployedAsset;
  let eth: DeployedAsset;
  let poolAddress: string;
  let simpleOracle: SimplePriceOracle;
  let oracle: MasterPriceOracle;
  let liquidator: FuseSafeLiquidator;
  let ethCToken: CEther;
  let tribeCToken: CErc20;
  let tribeUnderlying: EIP20Interface;
  let tx: providers.TransactionResponse;

  beforeEach(async () => {
    await setupTest();
    const { bob, deployer, rando } = await ethers.getNamedSigners();
    [poolAddress] = await createPool({});
    const assets = await getAssetsConf(poolAddress);
    const deployedAssets = await deployAssets(assets.assets, bob);

    tribe = deployedAssets.find((a) => a.symbol === "TRIBE");
    eth = deployedAssets.find((a) => a.underlying === constants.AddressZero);

    simpleOracle = (await ethers.getContract("SimplePriceOracle", deployer)) as SimplePriceOracle;
    const tx = await simpleOracle.setDirectPrice(tribe.underlying, "421407501053518");
    await tx.wait();

    oracle = (await ethers.getContract("MasterPriceOracle")) as MasterPriceOracle;
    liquidator = (await ethers.getContract("FuseSafeLiquidator", rando)) as FuseSafeLiquidator;
    ethCToken = (await ethers.getContractAt("CEther", eth.assetAddress)) as CEther;
    tribeCToken = (await ethers.getContractAt("CErc20", tribe.assetAddress)) as CErc20;
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
    await simpleOracle.setDirectPrice(tribe.underlying, BigNumber.from(originalPrice).div(10));

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
  it.only("should liquidate a token borrow for ETH collateral", async () => {
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // Supply ETH collateral
    await addCollateral(poolAddress, bob.address, "ETH", "0.0001", true);

    // Supply TRIBE from other account
    await addCollateral(poolAddress, alice.address, "TRIBE", "0.5", true);

    // Borrow TRIBE using ETH as collateral
    const borrowAmount = "0.1";
    await borrowCollateral(poolAddress, bob.address, "TRIBE", borrowAmount);

    // Set price of ETH collateral to 1/10th of what it was
    await simpleOracle.setDirectPrice("0x0000000000000000000000000000000000000000", utils.parseUnits("1", 17));

    const balBefore = await ethCToken.balanceOf(rando.address);
    const repayAmount = utils.parseEther(borrowAmount).div(10);
    console.log('repayAmount: ', repayAmount.toString());

    tx = await tribeUnderlying.connect(alice).transfer(rando.address, repayAmount);
    const bal = await tribeUnderlying.balanceOf(rando.address);
    console.log('bal: ', bal.toString());
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
  // it("should liquidate a token borrow for token collateral", async () => {
  //   await setupAndLiquidateUnhealthyTokenBorrowWithTokenCollateral();
  // });
});
