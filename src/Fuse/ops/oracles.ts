import { Contract, ContractFactory } from "ethers";
import { Interface } from "@ethersproject/abi";

import initializableClonesContract from "../../../artifacts/contracts/utils/InitializableClones.sol/InitializableClones.json";
import { OracleConf } from "../types";
import Fuse from "../index";
import MasterPriceOracle from "../../../artifacts/contracts/oracles/MasterPriceOracle.sol/MasterPriceOracle.json";

export const getOracleConf = (fuse: Fuse, model: string, conf: OracleConf): OracleConf => {
  switch (model) {
    case "UniswapTwapPriceOracle": // Uniswap V2 TWAPs
      // Input Validation
      if (!conf.uniswapV2Factory) conf.uniswapV2Factory = fuse.contractConfig.FACTORY.UniswapV2_Factory;
      return conf;
    case "UniswapV3TwapPriceOracleV2":
      // Input validation
      if (!conf.uniswapV3Factory) conf.uniswapV3Factory = fuse.contractConfig.FACTORY.UniswapV3_Factory;
      if ([500, 3000, 10000].indexOf(parseInt(conf.feeTier)) < 0)
        throw Error("Invalid fee tier passed to UniswapV3TwapPriceOracleV2 deployment.");
      return conf;
    case "UniswapTwapPriceOracleV2": // Uniswap V2 TWAPs
      // Input validation
      if (!conf.uniswapV2Factory) conf.uniswapV2Factory = fuse.contractConfig.FACTORY.UniswapV2_Factory;
      return conf;
    default:
      return conf;
  }
};

export const getDeployArgs = (fuse: Fuse, model: string, conf: OracleConf, options?: any) => {
  switch (model) {
    case "ChainlinkPriceOracle":
      return [conf.maxSecondsBeforePriceIsStale ? conf.maxSecondsBeforePriceIsStale : 0];
    case "UniswapLpTokenPriceOracle":
      return [!!conf.useRootOracle];

    case "UniswapTwapPriceOracle": // Uniswap V2 TWAPs
      // Input Validation
      if (!conf.uniswapV2Factory) conf.uniswapV2Factory = fuse.contractConfig.FACTORY.UniswapV2_Factory;
      return [
        fuse.contractConfig.PUBLIC_PRICE_ORACLE_CONTRACT_ADDRESSES.UniswapTwapPriceOracle_RootContract,
        conf.uniswapV2Factory,
      ];
    case "ChainlinkPriceOracleV2":
      return [conf.admin ? conf.admin : options.from, !!conf.canAdminOverwrite];
    case "UniswapV3TwapPriceOracle":
      // Input validation
      if (!conf.uniswapV3Factory) conf.uniswapV3Factory = fuse.contractConfig.FACTORY.UniswapV3_Factory;
      if ([500, 3000, 10000].indexOf(parseInt(conf.feeTier)) < 0)
        throw Error("Invalid fee tier passed to UniswapV3TwapPriceOracle deployment.");

      return [conf.uniswapV3Factory, conf.feeTier]; // Default to official Uniswap V3 factory
    case "FixedTokenPriceOracle":
      return [conf.baseToken];
    case "MasterPriceOracle":
      return [
        conf.underlyings ? conf.underlyings : [],
        conf.oracles ? conf.oracles : [],
        conf.defaultOracle ? conf.defaultOracle : "0x0000000000000000000000000000000000000000",
        conf.admin ? conf.admin : options.from,
        !!conf.canAdminOverwrite,
      ];
    default:
      return [];
  }
};

export const simpleDeploy = async (factory: ContractFactory, deployArgs: string[]) => {
  return await factory.deploy(deployArgs);
};

export const deployMasterPriceOracle = async (fuse: Fuse, conf: OracleConf, deployArgs: string[], options: any) => {
  const initializableClones = new Contract(
    fuse.contractConfig.COMPOUND_CONTRACT_ADDRESSES.InitializableClones,
    initializableClonesContract.abi,
    fuse.provider.getSigner()
  );
  const masterPriceOracle = new Interface(MasterPriceOracle.abi);
  const initializerData = masterPriceOracle.encodeDeploy(deployArgs);
  const receipt = await initializableClones.clone(
    fuse.contractConfig.FUSE_CONTRACT_ADDRESSES.MasterPriceOracleImplementation,
    initializerData
  );
  return new Contract(receipt.events["Deployed"].returnValues.instance, MasterPriceOracle.abi);
};
