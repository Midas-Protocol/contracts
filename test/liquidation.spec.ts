import { createPool, setupTest } from "./utils";

async function setupUnhealthyEthBorrowWithTokenCollateral(tokenCollateral) {
  // Default token collateral to DAI
  if (tokenCollateral === undefined) tokenCollateral = "0x6b175474e89094c44da98b954eedeac495271d0f";
  var originalPrice = testAssetFixtures.find(
    (item) => tokenCollateral.toLowerCase() === item.underlying.toLowerCase()
  ).price;

  // Supply token collateral
  var token = new fuse.web3.eth.Contract(erc20Abi, tokenCollateral);
  var cToken = new fuse.web3.eth.Contract(cErc20Abi, assetAddresses[tokenCollateral.toLowerCase()]);
  await token.methods
    .approve(cToken.options.address, Fuse.Web3.utils.toBN(2).pow(Fuse.Web3.utils.toBN(256)).subn(1))
    .send({ from: accounts[0], gasPrice: "0", gas: 10e6 });
  await cToken.methods
    .mint(Fuse.Web3.utils.toBN(3e14).mul(Fuse.Web3.utils.toBN(1e18)).div(Fuse.Web3.utils.toBN(originalPrice)))
    .send({ from: accounts[0], gasPrice: "0", gas: 10e6 });

  // Supply 0.001 ETH from other account
  var cToken = new fuse.web3.eth.Contract(cEtherAbi, assetAddresses["0x0000000000000000000000000000000000000000"]);
  await cToken.methods.mint().send({ from: accounts[1], gas: 5e6, gasPrice: "0", value: Fuse.Web3.utils.toBN(1e15) });

  // Borrow 0.0001 ETH using token collateral
  await comptroller.methods
    .enterMarkets([assetAddresses[tokenCollateral.toLowerCase()]])
    .send({ from: accounts[0], gasPrice: "0", gas: 10e6 });
  await cToken.methods.borrow(Fuse.Web3.utils.toBN(1e14)).send({ from: accounts[0], gasPrice: "0", gas: 10e6 });

  // Set price of token collateral to 1/10th of what it was
  await simplePriceOracle.methods
    .setDirectPrice(tokenCollateral, Fuse.Web3.utils.toBN(originalPrice).divn(10))
    .send({ from: accounts[0], gasPrice: "0", gas: 10e6 });
}

describe("#safeLiquidate", () => {
  beforeEach(async () => {
    await setupTest();
  });

  it("should liquidate an ETH borrow for token collateral", async () => {
    await createPool({});
    await setupAndLiquidateUnhealthyEthBorrowWithTokenCollateral();
  });
});
