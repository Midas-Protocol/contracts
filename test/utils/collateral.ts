import { constants, Contract, utils } from "ethers";
import { Fuse, USDPricedFuseAsset } from "../../lib/esm/src";
import { assetInPool, getPoolIndex } from "./pool";
import { HardhatEthersHelpers } from "@nomiclabs/hardhat-ethers/types";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

async function getAsset(
  ethers: HardhatEthersHelpers,
  sdk: Fuse,
  poolAddress: string,
  deployerAddress: string,
  underlyingSymbol: string
): Promise<USDPricedFuseAsset> {
  const poolId = (await getPoolIndex(poolAddress, deployerAddress, sdk)).toString();
  const assetsInPool = await sdk.fetchFusePoolData(poolId, deployerAddress);
  return assetsInPool.assets.filter((a) => a.underlyingSymbol === underlyingSymbol)[0];
}

function getCToken(asset: USDPricedFuseAsset, sdk: Fuse, signer: SignerWithAddress) {
  if (asset.underlyingToken === constants.AddressZero) {
    return new Contract(asset.cToken, sdk.chainDeployment.CEtherDelegate.abi, signer);
  } else {
    return new Contract(asset.cToken, sdk.chainDeployment.CErc20Delegate.abi, signer);
  }
}

export async function addCollateral(
  ethers: HardhatEthersHelpers,
  poolAddress: string,
  deployerAddress: string,
  underlyingSymbol: string,
  amount: string
) {
  let tx;

  const signer = await ethers.getSigner(deployerAddress);
  const sdk = new Fuse(ethers.provider, "1337");

  const assetToDeploy = await getAsset(ethers, sdk, poolAddress, deployerAddress, underlyingSymbol);
  const cToken = getCToken(assetToDeploy, sdk, signer);
  const pool = await ethers.getContractAt("Comptroller", poolAddress, signer);
  tx = await pool.enterMarkets([assetToDeploy.cToken]);
  await tx.wait();
  tx = await cToken.mint({ value: utils.parseUnits(amount, 18) });
  await tx.wait();
}

export async function borrowCollateral(
  ethers: HardhatEthersHelpers,
  poolAddress: string,
  deployerAddress: string,
  underlyingSymbol: string,
  amount: string
) {
  let tx;
  let rec;

  const signer = await ethers.getSigner(deployerAddress);
  const sdk = new Fuse(ethers.provider, "1337");
  const assetToDeploy = await getAsset(ethers, sdk, poolAddress, deployerAddress, underlyingSymbol);
  const cToken = getCToken(assetToDeploy, sdk, signer);

  tx = await cToken.callStatic.borrow(utils.parseUnits(amount, 18));
  expect(tx).to.eq(0);
  tx = await cToken.borrow(utils.parseUnits(amount, 18));
  rec = await tx.wait();
  expect(rec.status).to.eq(1);
  const poolId = await getPoolIndex(poolAddress, deployerAddress, sdk);
  const assetAfterBorrow = await assetInPool(poolId, sdk, signer, assetToDeploy.underlyingSymbol);
  console.log(assetAfterBorrow.borrowBalanceUSD, "Borrow Balance USD: AFTER mint & borrow");
  console.log(assetAfterBorrow.supplyBalanceUSD, "Supply Balance USD: AFTER mint & borrow");
}
