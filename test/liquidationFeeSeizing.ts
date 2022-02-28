import { BigNumber, constants, providers, utils } from "ethers";
import { ethers } from "hardhat";
import { createPool, deployAssets, setUpPriceOraclePrices } from "./utils";
import { DeployedAsset, getPoolAssets } from "./utils/pool";
import { setupAndLiquidatePool, setupLiquidatablePool } from "./utils/collateral";
import {
  CErc20,
  ERC20,
  FuseFeeDistributor,
  FuseSafeLiquidator,
  MasterPriceOracle,
  SimplePriceOracle,
} from "../typechain";
import { expect } from "chai";
import { FUSE_LIQUIDATION_PROTOCOL_FEE_PER_THOUSAND, FUSE_LIQUIDATION_SEIZE_FEE_PER_THOUSAND } from "./utils/config";
import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { cERC20Conf } from "../src";

describe("Protocol Liquidation Seizing", () => {
  let eth: cERC20Conf;

  let deployedEth: DeployedAsset;
  let deployedErc20One: DeployedAsset;

  let poolAddress: string;
  let simpleOracle: SimplePriceOracle;
  let oracle: MasterPriceOracle;
  let liquidator: FuseSafeLiquidator;
  let fuseFeeDistributor: FuseFeeDistributor;

  let erc20OneCToken: CErc20;

  let tx: providers.TransactionResponse;

  beforeEach(async () => {
    await setUpPriceOraclePrices();
    const { bob, deployer, rando } = await ethers.getNamedSigners();
    [poolAddress] = await createPool({});
    const assets = await getPoolAssets(poolAddress);
    const deployedAssets = await deployAssets(assets.assets, bob);

    const erc20One = assets.assets.find((a) => a.underlying !== constants.AddressZero); // find first one
    expect(erc20One.underlying).to.be.ok;
    const erc20Two = assets.assets.find(
      (a) => a.underlying !== constants.AddressZero && a.underlying !== erc20One.underlying
    ); // find second one

    oracle = (await ethers.getContract("MasterPriceOracle", deployer)) as MasterPriceOracle;
    expect(erc20Two.underlying).to.be.ok;
    const eth = assets.assets.find((a) => a.underlying === constants.AddressZero);

    await oracle.add([eth.underlying, erc20One.underlying, erc20Two.underlying], Array(3).fill(simpleOracle.address));

    let tx = await simpleOracle.setDirectPrice(eth.underlying, utils.parseEther("1"));
    await tx.wait();

    tx = await simpleOracle.setDirectPrice(erc20One.underlying, utils.parseEther("10"));
    await tx.wait();

    tx = await simpleOracle.setDirectPrice(erc20Two.underlying, utils.parseEther("0.0001"));
    await tx.wait();

    simpleOracle = (await ethers.getContract("SimplePriceOracle", deployer)) as SimplePriceOracle;
    tx = await simpleOracle.setDirectPrice(erc20One.underlying, "421407501053518");
    await tx.wait();

    deployedEth = deployedAssets.find((a) => a.underlying === constants.AddressZero);
    deployedErc20One = deployedAssets.find((a) => a.underlying === erc20One.underlying);

    fuseFeeDistributor = (await ethers.getContract("FuseFeeDistributor", deployer)) as FuseFeeDistributor;
    liquidator = (await ethers.getContract("FuseSafeLiquidator", rando)) as FuseSafeLiquidator;

    erc20OneCToken = (await ethers.getContractAt("CErc20", deployedErc20One.assetAddress)) as CErc20;
  });

  it("should calculate the right amounts of protocol, fee, total supply after liquidation", async function () {
    this.timeout(120_000);
    const { bob, rando } = await ethers.getNamedSigners();

    const borrowAmount = "0.0001";
    const repayAmount = utils.parseEther(borrowAmount).div(10);

    await setupLiquidatablePool(oracle, deployedErc20One, poolAddress, simpleOracle, borrowAmount);

    const liquidatorBalanceBefore = await erc20OneCToken.balanceOf(rando.address);
    const borrowerBalanceBefore = await erc20OneCToken.balanceOf(bob.address);
    const totalReservesBefore = await erc20OneCToken.totalReserves();
    const totalSupplyBefore = await erc20OneCToken.totalSupply();
    const feesBefore = await erc20OneCToken.totalFuseFees();

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

    const exchangeRate = await erc20OneCToken.exchangeRateStored();
    const borrowerBalanceAfter = await erc20OneCToken.balanceOf(bob.address);
    const liquidatorBalanceAfter = await erc20OneCToken.balanceOf(rando.address);
    const totalReservesAfter = await erc20OneCToken.totalReserves();
    const totalSupplyAfter = await erc20OneCToken.totalSupply();
    const feesAfter = await erc20OneCToken.totalFuseFees();

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
    await setupAndLiquidatePool(oracle, deployedErc20One, eth, poolAddress, simpleOracle, borrowAmount, liquidator);

    const feesAfterLiquidation = await erc20OneCToken.totalFuseFees();
    expect(feesAfterLiquidation).to.be.gt(BigNumber.from(0));
    console.log(feesAfterLiquidation.toString(), "FEES AFTER");

    tx = await erc20OneCToken._withdrawFuseFees(feesAfterLiquidation);
    const receipt: TransactionReceipt = await tx.wait();
    expect(receipt.status).to.eq(1);

    const feesAfterWithdrawal = await erc20OneCToken.totalFuseFees();
    expect(feesAfterLiquidation).to.be.gt(feesAfterWithdrawal);
    expect(feesAfterWithdrawal).to.eq(BigNumber.from(0));

    const tribeToken = (await ethers.getContract("TRIBEToken")) as ERC20;
    const fuseFeeDistributorBalance = await tribeToken.balanceOf(fuseFeeDistributor.address);
    expect(fuseFeeDistributorBalance).to.eq(feesAfterLiquidation);
  });
});
