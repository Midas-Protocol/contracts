import Caches from "../cache";
import axios from "axios";
import { utils } from "ethers";

export default class DydxSubpool {
  provider;
  cache;

  constructor(provider) {
    this.provider = provider;
    this.cache = new Caches({
      dydxCurrencyApys: 300,
    });
  }

  async getCurrencyApys() {
    return await this.cache.getOrUpdate("dydxCurrencyApys", async function () {
      const data = (await axios.get("https://api.dydx.exchange/v1/markets")).data;
      let apyBNs = {};

      for (let i = 0; i < data.markets.length; i++) {
        apyBNs[data.markets[i].symbol] = utils.parseUnits(data.markets[i].totalSupplyAPR, 77);
      }
      return apyBNs;
    });
  }
}
