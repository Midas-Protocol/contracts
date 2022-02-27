import { BigNumber, constants, providers, utils } from "ethers";
import { ethers } from "hardhat";
import { createPool, deployAssets, setupLocalOraclePrices } from "./utils";
import { DeployedAsset, getAssetsConf } from "./utils/pool";
import { setupAndLiquidatePool, setupLiquidatablePool } from "./utils/collateral";
import {
  CErc20,
  CEther,
  ERC20,
  FuseFeeDistributor,
  FuseSafeLiquidator,
  MasterPriceOracle,
  SimplePriceOracle,
} from "../typechain";
import { expect } from "chai";
import { FUSE_LIQUIDATION_PROTOCOL_FEE_PER_THOUSAND, FUSE_LIQUIDATION_SEIZE_FEE_PER_THOUSAND } from "./utils/config";
import { TransactionReceipt } from "@ethersproject/abstract-provider";

describe("Protocol Liquidation Seizing", () => {
  let tribe: DeployedAsset;
  let eth: DeployedAsset;
  let poolAddress: string;
  let simpleOracle: SimplePriceOracle;
  let oracle: MasterPriceOracle;
  let liquidator: FuseSafeLiquidator;
  let tribeCToken: CErc20;
  let ethCToken: CEther;
  let fuseFeeDistributor: FuseFeeDistributor;
  let tx: providers.TransactionResponse;

  beforeEach(async () => {
    await setupLocalOraclePrices();
    const { bob, deployer, rando } = await ethers.getNamedSigners();
    [poolAddress] = await createPool({});
    const assets = await getAssetsConf(poolAddress);
    const deployedAssets = await deployAssets(assets.assets, bob);

    tribe = deployedAssets.find((a) => a.symbol === "TRIBE");
    eth = deployedAssets.find((a) => a.underlying === constants.AddressZero);

    simpleOracle = (await ethers.getContract("SimplePriceOracle", deployer)) as SimplePriceOracle;
    tx = await simpleOracle.setDirectPrice(tribe.underlying, "421407501053518");
    await tx.wait();

    oracle = (await ethers.getContract("MasterPriceOracle")) as MasterPriceOracle;
    fuseFeeDistributor = (await ethers.getContract("FuseFeeDistributor", deployer)) as FuseFeeDistributor;
    liquidator = (await ethers.getContract("FuseSafeLiquidator", rando)) as FuseSafeLiquidator;
    tribeCToken = (await ethers.getContractAt("CErc20", tribe.assetAddress)) as CErc20;
    ethCToken = (await ethers.getContractAt("CEther", eth.assetAddress)) as CEther;
  });

  it("should calculate the right amounts of protocol, fee, total supply after liquidation", async function () {
    this.timeout(120_000);
    const { bob, rando } = await ethers.getNamedSigners();
    const { chainId } = await ethers.provider.getNetwork();

    const borrowAmount = "0.0001";
    const repayAmount = utils.parseEther(borrowAmount).div(10);

    await setupLiquidatablePool(oracle, tribe, poolAddress, simpleOracle, borrowAmount);

    const liquidatorBalanceBefore = await tribeCToken.balanceOf(rando.address);
    const borrowerBalanceBefore = await tribeCToken.balanceOf(bob.address);
    const totalReservesBefore = await tribeCToken.totalReserves();
    const totalSupplyBefore = await tribeCToken.totalSupply();
    const feesBefore = await tribeCToken.totalFuseFees();

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

    const exchangeRate = await tribeCToken.exchangeRateStored();
    const borrowerBalanceAfter = await tribeCToken.balanceOf(bob.address);
    const liquidatorBalanceAfter = await tribeCToken.balanceOf(rando.address);
    const totalReservesAfter = await tribeCToken.totalReserves();
    const totalSupplyAfter = await tribeCToken.totalSupply();
    const feesAfter = await tribeCToken.totalFuseFees();

    expect(liquidatorBalanceAfter).to.be.gt(liquidatorBalanceBefore);
    expect(totalReservesAfter).to.be.gt(totalReservesBefore);
    expect(feesAfter).to.be.gt(feesBefore);
    expect(borrowerBalanceBefore).to.be.gt(borrowerBalanceAfter);

    // seized tokens = borrower balance before - borrower balance after
    const seizedTokens = borrowerBalanceBefore.sub(borrowerBalanceAfter);
    const seizedAmount = parseFloat(utils.formatEther(seizedTokens.mul(exchangeRate)));

    // protocol seized = seized tokens * 2.8%
    const protocolSeizeTokens = seizedTokens.mul(FUSE_LIQUIDATION_PROTOCOL_FEE_PER_THOUSAND).div(1000);
    const protocolSeizeAmount = parseFloat(utils.formatEther(protocolSeizeTokens.mul(exchangeRate)));

    // fees seized = seized tokens * 10%
    const feeSeizeTokens = seizedTokens.mul(FUSE_LIQUIDATION_SEIZE_FEE_PER_THOUSAND).div(1000);
    const feeSeizeAmount = parseFloat(utils.formatEther(feeSeizeTokens.mul(exchangeRate)));

    // liquidator seized tokens = seized tokens - protocol seize tokens - fee seize tokens
    const liquidatorExpectedSeizeTokens = seizedTokens.sub(protocolSeizeTokens).sub(feeSeizeTokens);
    expect(liquidatorExpectedSeizeTokens).to.eq(liquidatorBalanceAfter.sub(liquidatorBalanceBefore));

    // same but with amounts using the exchange rate
    const liquidatorExpectedSeizeAmount = seizedAmount - protocolSeizeAmount - feeSeizeAmount;
    const liquidatorBalanceAfterAmount = parseFloat(utils.formatEther(liquidatorBalanceAfter.mul(exchangeRate)));
    // approximate
    expect(liquidatorExpectedSeizeAmount - liquidatorBalanceAfterAmount).to.be.lt(10e-9);

    // total supply before = total supply after - (protocol seize + fees seized)
    // rearranging: total supply before - total supply after + protocol seize + fees seized =~ 0
    const reminder = totalSupplyAfter.sub(totalSupplyBefore).add(protocolSeizeTokens).add(feeSeizeTokens);
    expect(reminder).to.be.eq(0);

    // generic
    expect(feesAfter).to.be.gt(feesBefore);
    // Protocol seized amount gets added to reserves
    const reservesDiffAmount = totalSupplyBefore.sub(totalReservesAfter);
    // gt because reserves get added on interest rate accrual
    expect(reservesDiffAmount).to.be.gt(protocolSeizeTokens);
  });
  it("should be able to withdraw fees to fuseFeeDistributor", async function () {
    this.timeout(120_000);
    const borrowAmount = "0.0001";
    const { chainId } = await ethers.provider.getNetwork();
    await setupAndLiquidatePool(oracle, tribe, eth, poolAddress, simpleOracle, borrowAmount, liquidator);

    const feesAfterLiquidation = await tribeCToken.totalFuseFees();
    expect(feesAfterLiquidation).to.be.gt(BigNumber.from(0));
    console.log(feesAfterLiquidation.toString(), "FEES AFTER");

    tx = await tribeCToken._withdrawFuseFees(feesAfterLiquidation);
    const receipt: TransactionReceipt = await tx.wait();
    expect(receipt.status).to.eq(1);

    const feesAfterWithdrawal = await tribeCToken.totalFuseFees();
    expect(feesAfterLiquidation).to.be.gt(feesAfterWithdrawal);
    expect(feesAfterWithdrawal).to.eq(BigNumber.from(0));

    const tribeToken = (await ethers.getContract("TRIBEToken")) as ERC20;
    const fuseFeeDistributorBalance = await tribeToken.balanceOf(fuseFeeDistributor.address);
    expect(fuseFeeDistributorBalance).to.eq(feesAfterLiquidation);
  });
});
