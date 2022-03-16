import { BigNumber, constants, Contract, providers, utils } from "ethers";
import { deployments, ethers } from "hardhat";
import { getPositionRatio, setUpLiquidation, tradeNativeForAsset } from "./utils";
import { addCollateral, borrowCollateral } from "./utils/collateral";
import {
  CErc20,
  CEther,
  EIP20Interface,
  FuseFeeDistributor,
  FuseSafeLiquidator,
  SimplePriceOracle,
} from "../typechain";
import { expect } from "chai";
import { cERC20Conf, ERC20Abi } from "../dist/esm/src";
import { DeployedAsset } from "./utils/pool";

const UNISWAP_V2_PROTOCOLS = {
  Uniswap: {
    router: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    factory: "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f",
  },
  SushiSwap: {
    router: "0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f",
    factory: "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac",
  },
  PancakeSwap: {
    router: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
    factory: "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73",
  },
};

(process.env.FORK_CHAIN_ID ? describe : describe.skip)("#safeLiquidate", () => {
  let tx: providers.TransactionResponse;

  let eth: cERC20Conf;
  let erc20One: cERC20Conf;
  let erc20Two: cERC20Conf;

  let deployedEth: DeployedAsset;
  let deployedErc20One: DeployedAsset;
  let deployedErc20Two: DeployedAsset;

  let poolAddress: string;
  let simpleOracle: SimplePriceOracle;
  let liquidator: FuseSafeLiquidator;
  let fuseFeeDistributor: FuseFeeDistributor;

  let ethCToken: CEther;
  let erc20OneCToken: CErc20;
  let erc20TwoCToken: CErc20;

  let erc20OneUnderlying: EIP20Interface;
  let erc20TwoUnderlying: EIP20Interface;

  const poolName = "liquidation - fl - " + Math.random().toString();
  const coingeckoId = "binancecoin";
  const uniswapV2RouterForCollateral = UNISWAP_V2_PROTOCOLS.PancakeSwap.router;

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
      simpleOracle,
      fuseFeeDistributor,
    } = await setUpLiquidation({ poolName }));
  });

  it.only("should liquidate a native borrow for token collateral", async function () {
    const { alice, bob, rando } = await ethers.getNamedSigners();

    // get some liquidity via Uniswap
    await tradeNativeForAsset({ account: "alice", token: erc20One.underlying, amount: "300" });

    // Supply 1 tokenOne from other account
    await addCollateral(poolAddress, alice, erc20One.symbol, "1", true, coingeckoId);
    console.log(`Added ${erc20One.symbol} collateral`);

    // Supply 10 native from other account
    await addCollateral(poolAddress, bob, eth.symbol, "10", false, coingeckoId);

    // Borrow 5 native using token collateral
    const borrowAmount = "5";
    await borrowCollateral(poolAddress, alice.address, eth.symbol, borrowAmount, coingeckoId);

    // Set price of tokenOne collateral to 6/10th of what it was
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, utils.parseEther("6"));
    await tx.wait();

    // account for gas fees
    const repayAmount = utils.parseEther(borrowAmount).mul(50).div(100);
    // Defaults
    // const exchangeTo = tokenCollateral;
    const exchangeTo = constants.AddressZero;

    // Check balance before liquidation

    const ratioBefore = await getPositionRatio({
      name: poolName,
      userAddress: undefined,
      cgId: coingeckoId,
      namedUser: "alice",
    });
    console.log(`Ratio Before: ${ratioBefore}`);

    const liquidatorBalanceBeforeLiquidation = await ethers.provider.getBalance(rando.address);

    const assetContract = new Contract(deployedEth.assetAddress, ERC20Abi, alice);
    tx = await assetContract.approve(alice.address, BigNumber.from(2).pow(BigNumber.from(256)).sub(constants.One));
    await tx.wait();

    const assetOneContract = new Contract(deployedErc20One.assetAddress, ERC20Abi, alice);
    tx = await assetOneContract.approve(alice.address, BigNumber.from(2).pow(BigNumber.from(256)).sub(constants.One));
    await tx.wait();

    // Liquidate borrow
    tx = await liquidator[
      "safeLiquidateToEthWithFlashLoan(address,uint256,address,address,uint256,address,address,address[],bytes[],uint256)"
    ](
      alice.address,
      repayAmount,
      deployedEth.assetAddress,
      deployedErc20One.assetAddress,
      0,
      exchangeTo,
      uniswapV2RouterForCollateral,
      [],
      [],
      0
    );
    const receipt = await tx.wait();
    expect(receipt.status).to.eq(1);
    // Assert balance after liquidation > balance before liquidation
    const liquidatorBalanceAfterLiquidation = await ethers.provider.getBalance(rando.address);

    expect(liquidatorBalanceAfterLiquidation).gt(liquidatorBalanceBeforeLiquidation);

    const ratioAfter = await getPositionRatio({
      name: poolName,
      userAddress: undefined,
      cgId: coingeckoId,
      namedUser: "alice",
    });
    console.log(`Ratio After: ${ratioAfter}`);
    expect(ratioBefore).to.be.gte(ratioAfter);
    // Set price of tokenOne collateral back to what it was
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, utils.parseEther("10"));
    await tx.wait();
  });

  // Safe liquidate token borrows
  it.only("should liquidate a token borrow for native collateral", async function () {
    const { alice, bob, rando } = await ethers.getNamedSigners();

    await tradeNativeForAsset({ account: "alice", token: erc20One.underlying, amount: "50" });
    // Supply native collateral
    await addCollateral(poolAddress, bob, eth.symbol, "10", true);

    // Supply tokenOne from other account
    await addCollateral(poolAddress, alice, erc20One.symbol, "0.1", true);

    // Borrow tokenOne using native as collateral
    const borrowAmount = "0.05";
    await borrowCollateral(poolAddress, bob.address, erc20One.symbol, borrowAmount);

    const originalPrice = await simpleOracle.getUnderlyingPrice(deployedErc20One.assetAddress);

    // Set price of borrowed token to 10x of what it was
    tx = await simpleOracle.setDirectPrice(deployedErc20One.underlying, BigNumber.from(originalPrice).mul(10));
    await tx.wait();

    const balBefore = await ethCToken.balanceOf(rando.address);
    const repayAmount = utils.parseEther(borrowAmount).div(10);

    await tx.wait();

    const assetContract = new Contract(deployedEth.assetAddress, ERC20Abi, alice);
    tx = await assetContract.approve(alice.address, BigNumber.from(2).pow(BigNumber.from(256)).sub(constants.One));
    await tx.wait();

    const assetOneContract = new Contract(deployedErc20One.assetAddress, ERC20Abi, alice);
    tx = await assetOneContract.approve(alice.address, BigNumber.from(2).pow(BigNumber.from(256)).sub(constants.One));
    await tx.wait();

    // Liquidate borrow
    tx = await liquidator["safeLiquidateToTokensWithFlashLoan"](
      bob.address,
      repayAmount,
      deployedErc20One.assetAddress,
      deployedEth.assetAddress,
      0,
      constants.AddressZero,
      uniswapV2RouterForCollateral,
      uniswapV2RouterForCollateral,
      [],
      [],
      0
    );
    await tx.wait();

    const balAfter = await ethCToken.balanceOf(rando.address);
    expect(balAfter).to.be.gt(balBefore);
  });
  //
  // it("should liquidate a token borrow for token collateral", async function () {
  //   const { alice, bob, rando } = await ethers.getNamedSigners();
  //   whale = await whaleSigner();
  //   if (!whale) {
  //     whale = alice;
  //   }
  //
  //   // send some tokens from whale to supplier
  //   tx = await erc20OneUnderlying.connect(whale).transfer(bob.address, utils.parseEther("1"));
  //
  //   const originalPrice = await oracle.getUnderlyingPrice(deployedErc20One.assetAddress);
  //
  //   // Supply tokenOne collateral
  //   await addCollateral(poolAddress, bob, erc20One.symbol, "0.5", true);
  //
  //   // Supply tokenTwo from other account
  //   await addCollateral(poolAddress, whale, erc20Two.symbol, "10000", false);
  //
  //   // Borrow tokenTwo using tokenOne collateral
  //   const borrowAmount = "5000";
  //   await borrowCollateral(poolAddress, bob.address, erc20Two.symbol, borrowAmount);
  //
  //   // Set price of tokenOne collateral to 1/10th of what it was
  //   tx = await simpleOracle.setDirectPrice(erc20One.underlying, BigNumber.from(originalPrice).div(10));
  //   await tx.wait();
  //
  //   const repayAmount = utils.parseEther(borrowAmount).div(15);
  //
  //   const balBefore = await erc20OneCToken.balanceOf(rando.address);
  //
  //   tx = await erc20TwoUnderlying.connect(whale).transfer(rando.address, repayAmount);
  //   tx = await erc20TwoUnderlying.connect(rando).approve(liquidator.address, constants.MaxUint256);
  //
  //   await tx.wait();
  //
  //   tx = await liquidator["safeLiquidate(address,uint256,address,address,uint256,address,address,address[],bytes[])"](
  //     bob.address,
  //     repayAmount,
  //     deployedErc20Two.assetAddress,
  //     deployedErc20One.assetAddress,
  //     0,
  //     deployedErc20One.assetAddress,
  //     constants.AddressZero,
  //     [],
  //     []
  //   );
  //
  //   const balAfter = await erc20OneCToken.balanceOf(rando.address);
  //   expect(balAfter).to.be.gt(balBefore);
  // });
});
