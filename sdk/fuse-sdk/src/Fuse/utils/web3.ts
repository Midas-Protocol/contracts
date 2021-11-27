import { BigNumber, BigNumberish, constants, Contract } from "ethers";
import { Web3Provider } from "@ethersproject/providers";

export const createContract = (address: string, abi: any, provider: Web3Provider) => new Contract(address, abi, provider);

export const toBN = (input: BigNumberish ) => {
  if (input === 0 || input === "0") return constants.Zero;
  if (input === 1e18) return constants.WeiPerEther;
  else return BigNumber.from(input);
};
