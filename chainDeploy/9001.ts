import { ChainDeployConfig } from "./helper";
import { BigNumber } from "ethers";

export const deployConfig9001: ChainDeployConfig = {
  wtoken: "",
  nativeTokenName: "EMVOS",
  nativeTokenSymbol: "PHO",
  blocksPerYear: BigNumber.from((8.6 * 24 * 365 * 60).toString()),
};
