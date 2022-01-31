import { BigNumber, constants, providers, utils } from "ethers";
import { ethers } from "hardhat";
import { createPool, deployAssets, setupTest } from "./utils";
import { Fuse } from "../lib/esm/src";
import { getAssetsConf } from "./utils/pool";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import { CErc20, CToken, MasterPriceOracle, SimplePriceOracle } from "../typechain";

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
    const { alice, bob } = await ethers.getNamedSigners();
    const [poolAddress] = await createPool({});
    const assets = await getAssetsConf(poolAddress);
    const deployedAssets = await deployAssets(assets.assets, bob);

    const c = await ethers.getContract("TRIBEToken");
    let bal = await c.balanceOf(bob.address);
    console.log("bob: ", bal.toString());
    bal = await c.balanceOf(alice.address);
    console.log("alice: ", bal.toString());
    const tribe = deployedAssets.find((a) => a.symbol === "TRIBE");

    const simpleOracle = (await ethers.getContract("SimplePriceOracle")) as SimplePriceOracle;
    tx = await simpleOracle.setDirectPrice(tribe.underlying, "421407501053518");
    console.log('tribe.underlying: ', tribe.underlying);
    await tx.wait();

    const ct = (await ethers.getContractAt("CErc20", tribe.assetAddress)) as CErc20;
    console.log('ct: ', await ct.underlying());

    const oracle = (await ethers.getContract("MasterPriceOracle")) as MasterPriceOracle;
    const direct = await oracle.price(tribe.underlying);
    console.log('direct: ', direct.toString());
    const originalPrice = await oracle.getUnderlyingPrice(tribe.implementationAddress);
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
    console.log("summary: ", summary);

    // summary = await sdk.contracts.FusePoolLensSecondary.callStatic.getMaxBorrow(bob.address, tribe.implementationAddress);
    // console.log("getMaxBorrow: ", summary);

    // Borrow 0.0001 ETH using token collateral
    await borrowCollateral(poolAddress, bob.address, "ETH", "0.0001");

    console.log("sdk.contracts.FusePoolLens: ", sdk.contracts.FusePoolLens.address);
    summary = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);
    console.log("summary: ", summary);
  });
});
