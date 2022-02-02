import { BigNumber, constants, providers, utils } from "ethers";
import { ethers } from "hardhat";
import { createPool, deployAssets, setupTest } from "./utils";
import { getAssetsConf } from "./utils/pool";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import {
  CToken,
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
  beforeEach(async () => {
    await setupTest();
  });

  it("should liquidate an ETH borrow for token collateral", async function () {
    this.timeout(120_000);
    let tx: providers.TransactionResponse;
    const { alice, bob, rando } = await ethers.getNamedSigners();
    const [poolAddress] = await createPool({});
    const assets = await getAssetsConf(poolAddress);
    const deployedAssets = await deployAssets(assets.assets, bob);

    const tribe = deployedAssets.find((a) => a.symbol === "TRIBE");
    const eth = deployedAssets.find((a) => a.underlying === constants.AddressZero);

    const simpleOracle = (await ethers.getContract("SimplePriceOracle")) as SimplePriceOracle;
    tx = await simpleOracle.setDirectPrice(tribe.underlying, "421407501053518");
    await tx.wait();

    const oracle = (await ethers.getContract("MasterPriceOracle")) as MasterPriceOracle;
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

    const collateralContract = (await ethers.getContractAt("CToken", tribe.assetAddress)) as CToken;
    const balBefore = await collateralContract.balanceOf(rando.address);
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
      { value: repayAmount, gasLimit: 10000000, gasPrice: utils.parseUnits("10", "gwei") }
    );
    await tx.wait();

    const balAfter = await collateralContract.balanceOf(rando.address);
    expect(balAfter).to.be.gt(balBefore);
  });
});
