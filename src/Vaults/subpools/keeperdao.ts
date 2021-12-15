/* eslint-disable */

import { JsonRpcProvider } from "@ethersproject/providers";
import { constants, BigNumber } from "ethers";

export default class KeeperDAOSubpool {
    provider: JsonRpcProvider

  constructor(provider: JsonRpcProvider) {
    this.provider = provider;
  }

  getCurrencyApys = (): {ETH: BigNumber} => {
    // TODO: KeeperDAO APYs
    return {
      ETH: constants.Zero,
    };
  }
}
