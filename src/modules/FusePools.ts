import { BigNumber, BigNumberish, constants, Contract, ethers, utils } from "ethers";
import { FusePoolLens } from "../../typechain/FusePoolLens";
import { FusePoolDirectory } from "../../typechain/FusePoolDirectory";
import { FuseBaseConstructor } from "../Fuse/types";
import { filterOnlyObjectProperties, filterPoolName } from "../Fuse/utils";
import { FusePoolData, USDPricedFuseAsset } from "../Fuse/types";

export type LensPoolsWithData = [
  ids: BigNumberish[],
  fusePools: FusePoolDirectory.FusePoolStructOutput[],
  fusePoolsData: FusePoolLens.FusePoolDataStructOutput[],
  errors: boolean[]
];

export function withFusePools<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class FusePools extends Base {
    async fetchFusePoolData(poolId: string, address?: string): Promise<FusePoolData> {
      const {
        comptroller,
        name: _unfiliteredName,
        creator,
        blockPosted,
        timestampPosted,
      } = await this.contracts.FusePoolDirectory.pools(Number(poolId));

      const rawData = await this.contracts.FusePoolLens.callStatic.getPoolSummary(comptroller);
      const underlyingTokens = rawData[2];
      const underlyingSymbols = rawData[3];
      const whitelistedAdmin = rawData[4];

      const name = filterPoolName(_unfiliteredName);

      const assets: USDPricedFuseAsset[] = (
        await this.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(comptroller, {
          from: address,
        })
      ).map(filterOnlyObjectProperties);

      let totalLiquidityUSD = 0;
      let totalSupplyBalanceUSD = 0;
      let totalBorrowBalanceUSD = 0;
      let totalSuppliedUSD = 0;
      let totalBorrowedUSD = 0;

      const promises: Promise<boolean>[] = [];

      const comptrollerContract = new Contract(
        comptroller,
        this.chainDeployment.Comptroller.abi,
        this.provider.getSigner()
      );
      for (let i = 0; i < assets.length; i++) {
        const asset = assets[i];

        // @todo aggregate the borrow/supply guardian paused into 1
        promises.push(
          comptrollerContract.callStatic
            .borrowGuardianPaused(asset.cToken)
            .then((isPaused: boolean) => (asset.isPaused = isPaused))
        );
        promises.push(
          comptrollerContract.callStatic
            .mintGuardianPaused(asset.cToken)
            .then((isPaused: boolean) => (asset.isSupplyPaused = isPaused))
        );

        asset.supplyBalanceUSD =
          Number(utils.formatUnits(asset.supplyBalance)) * Number(utils.formatUnits(asset.underlyingPrice));

        asset.borrowBalanceUSD =
          Number(utils.formatUnits(asset.borrowBalance)) * Number(utils.formatUnits(asset.underlyingPrice));

        totalSupplyBalanceUSD += asset.supplyBalanceUSD;
        totalBorrowBalanceUSD += asset.borrowBalanceUSD;

        asset.totalSupplyUSD =
          Number(utils.formatUnits(asset.totalSupply)) * Number(utils.formatUnits(asset.underlyingPrice));
        asset.totalBorrowUSD =
          Number(utils.formatUnits(asset.totalBorrow)) * Number(utils.formatUnits(asset.underlyingPrice));

        totalSuppliedUSD += asset.totalSupplyUSD;
        totalBorrowedUSD += asset.totalBorrowUSD;

        asset.liquidityUSD =
          Number(utils.formatUnits(asset.liquidity)) * Number(utils.formatUnits(asset.underlyingPrice));

        totalLiquidityUSD += asset.liquidityUSD;
      }

      await Promise.all(promises);

      return {
        id: Number(poolId),
        assets: assets.sort((a, b) => (b.liquidityUSD > a.liquidityUSD ? 1 : -1)),
        creator,
        comptroller,
        name,
        totalLiquidityUSD,
        totalSuppliedUSD,
        totalBorrowedUSD,
        totalSupplyBalanceUSD,
        totalBorrowBalanceUSD,
        blockPosted,
        timestampPosted,
        underlyingTokens,
        underlyingSymbols,
        whitelistedAdmin,
      };
    }

    async fetchPoolsManual({
      verification,
      options,
    }: {
      verification: boolean;
      options: { from: string };
    }): Promise<(FusePoolData | null)[] | undefined> {
      const fusePoolsDirectoryResult = await this.contracts.FusePoolDirectory.callStatic.getPublicPoolsByVerification(
        verification,
        {
          from: options.from,
        }
      );
      const poolIds: string[] = (fusePoolsDirectoryResult[0] ?? []).map((bn: BigNumber) => bn.toString());

      if (!poolIds.length) {
        return undefined;
      }

      const poolData = await Promise.all(
        poolIds.map((_id, i) => {
          return this.fetchFusePoolData(_id, options.from);
        })
      );

      return poolData;
    }

    async fetchPools({
      filter,
      options,
    }: {
      filter: string | null;
      options: { from: string };
    }): Promise<FusePoolData[]> {
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

      const responses = await Promise.all([req, whitelistedPoolsRequest]);

      const [pools, whitelistedPools] = await Promise.all(
        responses.map(async (poolData) => {
          return await Promise.all(
            poolData[0].map((_id) => {
              return this.fetchFusePoolData(_id.toString(), options.from);
            })
          );
        })
      );

      const whitelistedIds = whitelistedPools.map((pool) => pool?.id);
      const filteredPools = pools.filter((pool) => !whitelistedIds.includes(pool?.id));

      return [...filteredPools, ...whitelistedPools];
    }
  };
}
