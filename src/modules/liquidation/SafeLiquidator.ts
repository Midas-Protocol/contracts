import { BigNumber, utils } from "ethers";
import { FuseBaseConstructor } from "../../Fuse/types";
import { gatherLiquidations } from "./index";
import { LiquidatablePool, PublicPoolUserWithData } from "./utils";
import { ChainLiquidationConfig, getChainLiquidationConfig } from "./config";
import liquidateUnhealthyBorrows from "./liquidateUnhealthyBorrows";

// import getPotentialLiquidations from "./getPotentialLiquidations";

export function withSafeLiquidator<TBase extends FuseBaseConstructor>(Base: TBase) {
  return class SafeLiquidator extends Base {
    async getPotentialLiquidations(
      supportedComptrollers: Array<string> = [],
      maxHealthFactor: BigNumber = utils.parseEther("1"),
      chainLiquidationConfig?: ChainLiquidationConfig
    ): Promise<Array<LiquidatablePool>> {
      // Get potential liquidations from public pools
      const [comptrollers, users, closeFactors, liquidationIncentives] =
        await this.contracts.FusePoolLens.callStatic.getPublicPoolUsersWithData(maxHealthFactor);
      if (supportedComptrollers.length === 0) supportedComptrollers = comptrollers;
      if (!chainLiquidationConfig) chainLiquidationConfig = getChainLiquidationConfig(this.chainId);
      const publicPoolUsersWithData: Array<PublicPoolUserWithData> = comptrollers
        .map((c, i) => {
          return supportedComptrollers.includes(c)
            ? {
                comptroller: c,
                users: users[i],
                closeFactor: closeFactors[i],
                liquidationIncentive: liquidationIncentives[i],
              }
            : null;
        })
        .filter((x): x is PublicPoolUserWithData => x !== null);

      return await gatherLiquidations(this, publicPoolUsersWithData, chainLiquidationConfig);
    }
    async estimateProfit(liquidation) {}
    async liquidatePositions(positions: Array<LiquidatablePool>) {
      await liquidateUnhealthyBorrows(this, positions);
    }
    async getPositionRation(position) {}
  };
}
