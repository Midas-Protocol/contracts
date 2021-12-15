import Caches from "../cache";
import axios from "axios";
import { utils } from "ethers";

export default class CompoundSubpool {
  provider;
  cache;

  constructor(provider) {
    this.provider = provider;
    this.cache = new Caches({
      compoundCurrencySupplierAndCompApys: 300,
    });
  }

  async getCurrencySupplierAndCompApys() {
    return await this.cache.getOrUpdate("compoundCurrencySupplierAndCompApys", async function () {
      const data = (await axios.get("https://api.compound.finance/api/v2/ctoken")).data;

      let apyBNs = {};

      for (let i = 0; i < data.cToken.length; i++) {
        const supplyApy = utils.parseUnits(data.cToken[i].supply_rate.value, 28);
        const compApy = utils.parseUnits(
          data.cToken[i].comp_supply_apy.value,
          data.cToken[i].comp_supply_apy.value.length - 1,
        );
        apyBNs[data.cToken[i].underlying_symbol] = [supplyApy, compApy];
      }
      return apyBNs;
    });
  }
  async getCurrencyApys() {
    const compoundApyBNs = await this.getCurrencySupplierAndCompApys();
    let compoundCombinedApyBNs = {};
    for (const currencyCode of Object.keys(compoundApyBNs)) {
      compoundCombinedApyBNs[currencyCode] = compoundApyBNs[currencyCode][0].add(compoundApyBNs[currencyCode][1]);
    }

    return compoundCombinedApyBNs;
  }
}
