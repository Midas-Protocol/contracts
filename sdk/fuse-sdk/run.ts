import { Fuse } from ".";
import mainnet from "../../network/mainnet.json";
import { ethers } from "hardhat";

const FuseInstance = new Fuse(ethers.provider, mainnet.Contracts);

interface FusePool {
  name: string;
  creator: string;
  compotroller: string;
  isPrivate: boolean;
}

export interface MergedPool {
  id: number;
  pool: FusePool;
  underlyingTokens: string[];
  underlyingSymbols: string[];
  suppliedUSD: number;
  borrowedUSD: number;
}

export function filterOnlyObjectProperties(obj: any) {
  return Object.fromEntries(Object.entries(obj).filter(([k]) => isNaN(k as any))) as any;
}

const fetchPools = async () => {
  const [
    { 0: ids, 1: fusePools, 2: totalSuppliedETH, 3: totalBorrowedETH, 4: underlyingTokens, 5: underlyingSymbols },
    ethPrice,
  ] = await Promise.all([
    FuseInstance.contracts.FusePoolLens.callStatic.getPublicPoolsWithData(),
    (parseInt((await FuseInstance.getEthUsdPriceBN()).toString()) * 1e-2).toFixed(2),
  ]);

  console.log(ids, fusePools, totalSuppliedETH, totalBorrowedETH, underlyingSymbols, underlyingTokens, ethPrice);

  const merged: MergedPool[] = [];
  for (let id = 0; id < ids.length; id++) {
    merged.push({
      underlyingTokens: underlyingTokens[id],
      underlyingSymbols: underlyingSymbols[id],
      pool: filterOnlyObjectProperties(fusePools[id]),
      id: ids[id],
      suppliedUSD: (totalSuppliedETH[id] / 1e18) * parseFloat(ethPrice),
      borrowedUSD: (totalBorrowedETH[id] / 1e18) * parseFloat(ethPrice),
    });
  }

  console.log(merged);
};

fetchPools();
