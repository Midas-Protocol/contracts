import { JsonRpcProvider } from "@ethersproject/providers";
import { Contract } from "ethers";
import Cache from "../cache";

// ABIs
import BankABI from "./alpha/abi/Bank.json";
import ConfigurableInterestBankConfig from "./alpha/abi/ConfigurableInterestBankConfig.json";

const externalContractAddressesAlpha = {
  Bank: "0x67B66C99D3Eb37Fa76Aa3Ed1ff33E8e39F0b9c7A",
  ConfigurableInterestBankConfig: "0x97a49f8eec63c0dfeb9db4c791229477962dc692",
};

const externalAbisAlpha = {
  Bank: BankABI,
  ConfigurableInterestBankConfig: ConfigurableInterestBankConfig,
};

export default class AlphaSubpool {
  provider: JsonRpcProvider;
  cache: Cache;
  externalContracts;

  constructor(provider: JsonRpcProvider) {
    this.provider = provider;
    this.cache = new Cache({
      alphaIBEthApy: 300,
    });

    this.externalContracts = {};
    for (const contractName of Object.keys(externalContractAddressesAlpha)) {
      this.externalContracts[contractName] = new Contract(
        externalContractAddressesAlpha[contractName],
        externalAbisAlpha[contractName],
        this.provider,
      );
    }
  }

  async getCurrencyApys() {
    return { ETH: await this.getIBEthApyBN() };
  }

  async getIBEthApyBN() {
    let self = this;
    return await this.cache.getOrUpdate("alphaIBEthApy", async function () {
      try {
        const glbDebtVal = await self.externalContracts.Bank.glbDebtVal();
        const balance = await self.provider.getBalance(self.externalContracts.Bank.address);
        // as this is no longer being used I'll leave it as is
        const interestRatePerSecondBN =
          await self.externalContracts.ConfigurableInterestBankConfig.callStatic.getInterestRate(glbDebtVal, balance);
        return balance;
      } catch (e) {
        throw new Error("Failed to get Alpha Homora V1 interest rate: " + e);
      }
    });
  }
}
