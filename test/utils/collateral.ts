import { BigNumber, constants, Contract, providers, utils } from "ethers";
import { ERC20Abi, Fuse, USDPricedFuseAsset } from "../../lib/esm/src";
import { assetInPool, getPoolIndex } from "./pool";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { MasterPriceOracle, SimplePriceOracle } from "../../typechain";

export async function getAsset(sdk: Fuse, poolAddress: string, underlyingSymbol: string): Promise<USDPricedFuseAsset> {
  const poolId = (await getPoolIndex(poolAddress, sdk)).toString();
  const assetsInPool = await sdk.fetchFusePoolData(poolId);
  return assetsInPool.assets.filter((a) => a.underlyingSymbol === underlyingSymbol)[0];
}

export function getCToken(asset: USDPricedFuseAsset, sdk: Fuse, signer: SignerWithAddress) {
  if (asset.underlyingToken === constants.AddressZero) {
    return new Contract(asset.cToken, sdk.chainDeployment.CEtherDelegate.abi, signer);
  } else {
    return new Contract(asset.cToken, sdk.chainDeployment.CErc20Delegate.abi, signer);
  }
}

export async function addCollateral(
  poolAddress: string,
  depositor: SignerWithAddress,
  underlyingSymbol: string,
  amount: string,
  useAsCollateral: boolean
) {
  let tx: providers.TransactionResponse;
  let amountBN: BigNumber;
  let cToken: Contract;

  const { chainId } = await ethers.provider.getNetwork();

  const sdk = new Fuse(ethers.provider, chainId);

  const assetToDeploy = await getAsset(sdk, poolAddress, underlyingSymbol);

  cToken = getCToken(assetToDeploy, sdk, depositor);
  const pool = await ethers.getContractAt("Comptroller", poolAddress, depositor);
  if (useAsCollateral) {
    tx = await pool.enterMarkets([assetToDeploy.cToken]);
    await tx.wait();
  }
  amountBN = utils.parseUnits(amount, 18);
  await approveAndMint(amountBN, cToken, assetToDeploy.underlyingToken, depositor);
}

export async function approveAndMint(
  amount: BigNumber,
  cTokenContract: Contract,
  underlyingToken: string,
  signer: SignerWithAddress
) {
  let tx: providers.TransactionResponse;

  if (underlyingToken === constants.AddressZero) {
    tx = await cTokenContract.approve(signer.address, BigNumber.from(2).pow(BigNumber.from(256)).sub(constants.One));
    await tx.wait();
    tx = await cTokenContract.mint({ value: amount, from: signer.address });
  } else {
    const assetContract = new Contract(underlyingToken, ERC20Abi, signer);
    tx = await assetContract.approve(
      cTokenContract.address,
      BigNumber.from(2).pow(BigNumber.from(256)).sub(constants.One)
    );
    await tx.wait();
    tx = await cTokenContract.mint(amount);
  }
  return tx.wait();
}

export async function borrowCollateral(
  poolAddress: string,
  borrowerAddress: string,
  underlyingSymbol: string,
  amount: string
) {
  let tx: providers.TransactionResponse;
  let rec: providers.TransactionReceipt;

  const { chainId } = await ethers.provider.getNetwork();
  const signer = await ethers.getSigner(borrowerAddress);
  const sdk = new Fuse(ethers.provider, chainId);
  const assetToDeploy = await getAsset(sdk, poolAddress, underlyingSymbol);

  const pool = await ethers.getContractAt("Comptroller", poolAddress, signer);
  tx = await pool.enterMarkets([assetToDeploy.cToken]);
  await tx.wait();

  const cToken = getCToken(assetToDeploy, sdk, signer);
  tx = await cToken.callStatic.borrow(utils.parseUnits(amount, 18));
  expect(tx).to.eq(0);
  tx = await cToken.borrow(utils.parseUnits(amount, 18));
  rec = await tx.wait();
  expect(rec.status).to.eq(1);
  const poolId = await getPoolIndex(poolAddress, sdk);
  const assetAfterBorrow = await assetInPool(poolId, sdk, assetToDeploy.underlyingSymbol, signer.address);
  console.log(assetAfterBorrow.borrowBalanceUSD, "Borrow Balance USD: AFTER mint & borrow");
  console.log(assetAfterBorrow.supplyBalanceUSD, "Supply Balance USD: AFTER mint & borrow");
}

export async function setupLiquidatablePool(
  oracle: MasterPriceOracle,
  tribe: any,
  poolAddress: string,
  simpleOracle: SimplePriceOracle,
  borrowAmount: string
) {
  const { alice, bob } = await ethers.getNamedSigners();
  const { chainId } = await ethers.provider.getNetwork();
  let tx: providers.TransactionResponse;
  const originalPrice = await oracle.getUnderlyingPrice(tribe.assetAddress);

  await addCollateral(
    poolAddress,
    bob,
    "TRIBE",
    utils.formatEther(BigNumber.from(3e14).mul(constants.WeiPerEther.div(originalPrice))),
    true
  );

  // Supply 0.001 ETH from other account
  await addCollateral(poolAddress, alice, "ETH", "0.001", false);

  // Borrow 0.0001 ETH using token collateral
  await borrowCollateral(poolAddress, bob.address, "ETH", borrowAmount);

  // Set price of token collateral to 1/10th of what it was
  tx = await simpleOracle.setDirectPrice(tribe.underlying, BigNumber.from(originalPrice).div(10));
  await tx.wait();
}

export async function setupAndLiquidatePool(
  oracle: MasterPriceOracle,
  tribe: any,
  eth: any,
  poolAddress: string,
  simpleOracle: SimplePriceOracle,
  borrowAmount: string,
  liquidator: any
) {
  const { bob } = await ethers.getNamedSigners();
  await setupLiquidatablePool(oracle, tribe, poolAddress, simpleOracle, borrowAmount);

  const repayAmount = utils.parseEther(borrowAmount).div(10);

  const tx = await liquidator["safeLiquidate(address,address,address,uint256,address,address,address[],bytes[])"](
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
}
