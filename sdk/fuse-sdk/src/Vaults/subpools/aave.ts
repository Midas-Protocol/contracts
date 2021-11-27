import Caches from "../cache";
import axios from "axios";
import { BigNumber } from "ethers";

export default class AaveSubpool {
  ethers;
  cache;

  constructor(ethers) {
    this.ethers = ethers;
    this.cache = new Caches({
      aaveCurrencyApys: 300,
    });
  }

  async getCurrencyApys() {
    return await this.cache.getOrUpdate("aaveCurrencyApys", async function () {
      let currencyCodes = ["DAI", "USDC", "USDT", "TUSD", "BUSD", "SUSD", "mUSD", "ETH"];

      const data: {
        data: {
          reserves: any[]
        }
      } = (
        await axios.post("https://api.thegraph.com/subgraphs/name/aave/protocol-multy-raw", {
          query:
            `{
                                reserves(where: {
                                    symbol_in: ` +
            JSON.stringify(currencyCodes) +
            ` }) {
                                    id
                                    symbol
                                    liquidityRate
                                }
                            }`,
        })
      ).data;

      let apyBNs = {};

      for (let i = 0; i < data.data.reserves.length; i++) {
        if (
          data.data.reserves[i].symbol === "ETH" &&
          data.data.reserves[i].id !==
            "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0x24a42fd28c976a61df5d00d0599c34c4f90748c8"
        )
          continue;

        apyBNs[data.data.reserves[i].symbol == "SUSD" ? "sUSD" : data.data.reserves[i].symbol] = BigNumber.from(
          data.data.reserves[i].liquidityRate,
        ).div(BigNumber.from(1e9));
      }

      return apyBNs;
    });
  }
}
