import { BigNumber, constants, providers, utils } from "ethers";
import { ethers } from "hardhat";
import { createPool, deployAssets, setupTest } from "./utils";
import { Fuse } from "../lib/esm/src";
import { getAssetsConf } from "./utils/pool";
import { addCollateral, borrowCollateral, getAsset, getCToken } from "./utils/collateral";
import { CErc20, CEther, CToken, FuseSafeLiquidator, MasterPriceOracle, SimplePriceOracle } from "../typechain";

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
  beforeEach(async () => {
    await setupTest();
  });

  it.only("should liquidate an ETH borrow for token collateral", async function () {
    this.timeout(120_000);
    let tx: providers.TransactionResponse;
    const sdk = new Fuse(ethers.provider, "1337");
    const { alice, bob, rando } = await ethers.getNamedSigners();
    const [poolAddress] = await createPool({});
    const assets = await getAssetsConf(poolAddress);
    const deployedAssets = await deployAssets(assets.assets, bob);

    const tribe = deployedAssets.find((a) => a.symbol === "TRIBE");
    const touch = deployedAssets.find((a) => a.symbol === "TOUCH");
    const eth = deployedAssets.find((a) => a.underlying === constants.AddressZero);

    const simpleOracle = (await ethers.getContract("SimplePriceOracle")) as SimplePriceOracle;
    tx = await simpleOracle.setDirectPrice(tribe.underlying, "421407501053518");
    await tx.wait();
    
    console.log("tribe.assetAddress: ", tribe.assetAddress);
    console.log("touch.assetAddress: ", touch.assetAddress);
    console.log("eth.assetAddress: ", eth.assetAddress);

    const ceth = (await ethers.getContractAt("CEther", eth.assetAddress) ) as CEther;
    const under = await ceth.underlying();
    console.log('under: ', under);

    const oracle = (await ethers.getContract("MasterPriceOracle")) as MasterPriceOracle;
    const originalPrice = await oracle.getUnderlyingPrice(tribe.assetAddress);
    console.log("originalPrice: ", originalPrice.toString());

    await addCollateral(
      poolAddress,
      bob.address,
      "TRIBE",
      utils.formatEther(BigNumber.from(3e14).mul(constants.WeiPerEther.div(originalPrice))),
      true
    );

    // Supply 0.001 ETH from other account
    await addCollateral(poolAddress, alice.address, "ETH", "0.001", false);

    let summary = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);

    // Borrow 0.0001 ETH using token collateral
    await borrowCollateral(poolAddress, bob.address, "ETH", "0.0001");

    summary = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);
    console.log("summary: ", summary);

    // Set price of token collateral to 1/10th of what it was
    await simpleOracle.setDirectPrice(tribe.underlying, BigNumber.from(originalPrice).div(10));
    summary = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);

    const tokenCollateral = await ethers.getContractAt("EIP20Interface", tribe.underlying);
    const liquidatorBalanceBeforeLiquidation = await tokenCollateral.balanceOf(rando.address);
    console.log("liquidatorBalanceBeforeLiquidation: ", liquidatorBalanceBeforeLiquidation.toString());
    const repayAmount = utils.parseEther("0.0001");
    console.log("repayAmount: ", repayAmount.toString());

    const liquidator = (await ethers.getContract("FuseSafeLiquidator", rando)) as FuseSafeLiquidator;
    tx = await liquidator["safeLiquidate(address,address,address,uint256,address,address,address[],bytes[])"](
      bob.address,
      eth.assetAddress,
      tribe.assetAddress,
      0,
      tribe.assetAddress,
      constants.AddressZero,
      [],
      [],
      { value: repayAmount }
    );
    await tx.wait();
    console.log("tx: ", tx);
    summary = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);
    console.log("summary: ", summary);
  });
});
