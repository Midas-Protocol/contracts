import { BigNumber, BigNumberish } from "ethers";
import { FusePoolLens } from "../../typechain/FusePoolLens";
import { FusePoolDirectory } from "../../typechain/FusePoolDirectory";
import { FuseBaseConstructor } from "../Fuse/types";
import { filterOnlyObjectProperties } from "../Fuse/utils";

export type LensPoolsWithData = [
  ids: BigNumberish[],
  fusePools: FusePoolDirectory.FusePoolStructOutput[],
  fusePoolsData: FusePoolLens.FusePoolDataStructOutput[],
  errors: boolean[]
];

export interface MergedPool {
  id: number;
  name: string;
  creator: string;
  comptroller: string;
  blockPosted: BigNumber;
  timestampPosted: BigNumber;
  suppliedUSD: number;
  borrowedUSD: number;
  totalSupply: BigNumber;
  totalBorrow: BigNumber;
  underlyingTokens: string[];
  underlyingSymbols: string[];
  whitelistedAdmin: boolean;
}

export function withFusePools<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class FusePools extends Base {
    async fetchPoolsManual(verification: boolean, nativeAssetPriceInUSD: number, options: { from: string }) {
      const fusePoolsDirectoryResult = await this.contracts.FusePoolDirectory.callStatic.getPublicPoolsByVerification(
        verification,
        {
          from: options.from,
        }
      );
      const poolIds: string[] = (fusePoolsDirectoryResult[0] ?? []).map((bn: BigNumber) => bn.toString());
      const fusePools = fusePoolsDirectoryResult[1];
      const comptrollers = fusePools.map(({ comptroller }) => comptroller);
      const fusePoolsData: FusePoolLens.FusePoolDataStructOutput[] = [];

      for (const comptroller of comptrollers) {
        try {
          const rawData = await this.contracts.FusePoolLens.callStatic.getPoolSummary(comptroller);
          const data: any = [...rawData];
          data.totalSupply = rawData[0];
          data.totalBorrow = rawData[1];
          data.underlyingTokens = rawData[2];
          data.underlyingSymbols = rawData[3];
          data.whitelistedAdmin = rawData[4];
          fusePoolsData.push(data as FusePoolLens.FusePoolDataStructOutput);
        } catch (err) {
          console.error(`Error querying poolSummaries for Pool: ${comptroller}`, err);
          return [];
        }
      }

      return this.mergePoolData([poolIds, fusePools, fusePoolsData, []], nativeAssetPriceInUSD);
    }

    mergePoolData(data: LensPoolsWithData, nativeAssetPriceInUSD: number): MergedPool[] {
      const [ids, fusePools, fusePoolsData] = data;

      return ids.map((_id, i) => {
        const id = parseFloat(ids[i].toString());
        const fusePool = fusePools[i];
        const fusePoolData = fusePoolsData[i];

        return {
          id,
          suppliedUSD:
            (parseFloat(fusePoolData.totalSupply ? fusePoolData.totalSupply.toString() : fusePoolData[0].toString()) /
              1e18) *
            nativeAssetPriceInUSD,
          borrowedUSD:
            (parseFloat(fusePoolData.totalBorrow ? fusePoolData.totalBorrow.toString() : fusePoolData[1].toString()) /
              1e18) *
            nativeAssetPriceInUSD,
          ...filterOnlyObjectProperties(fusePool),
          ...filterOnlyObjectProperties(fusePoolData),
        };
      });
    }

    async fetchPools(filter: string | null, nativeAssetPriceInUSD: number, options: { from: string }) {
      const isCreatedPools = filter === "created-pools";
      const isVerifiedPools = filter === "verified-pools";
      const isUnverifiedPools = filter === "unverified-pools";

      const req = isCreatedPools
        ? this.contracts.FusePoolLens.callStatic.getPoolsByAccountWithData(options.from)
        : isVerifiedPools
        ? this.contracts.FusePoolLens.callStatic.getPublicPoolsByVerificationWithData(true)
        : isUnverifiedPools
        ? this.contracts.FusePoolLens.callStatic.getPublicPoolsByVerificationWithData(false)
        : this.contracts.FusePoolLens.callStatic.getPublicPoolsWithData();

      const whitelistedPoolsRequest = this.contracts.FusePoolLens.callStatic.getWhitelistedPoolsByAccountWithData(
        options.from
      );

      const [pools, whitelistedPools] = await Promise.all([req, whitelistedPoolsRequest]).then((responses) =>
        responses.map((poolData) => this.mergePoolData(poolData, nativeAssetPriceInUSD))
      );

      const whitelistedIds = whitelistedPools.map((pool) => pool.id);
      const filteredPools = pools.filter((pool) => !whitelistedIds.includes(pool.id));

      return [...filteredPools, ...whitelistedPools];
    }
  };
}
