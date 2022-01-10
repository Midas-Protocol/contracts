import MasterPriceOracleArtifact from "../artifacts/contracts/oracles/MasterPriceOracle.sol/MasterPriceOracle.json";
import MockPriceOracleArtifact from "../artifacts/contracts/oracles/MockPriceOracle.sol/MockPriceOracle.json";
import { utils } from "ethers";

export const oracleConfig = {
  1337: {
    DEPLOYED_ORACLES_BYTECODE_HASHES: {
      MockPriceOracle: utils.keccak256(MockPriceOracleArtifact.bytecode),
      MasterPriceOracle: utils.keccak256(MasterPriceOracleArtifact.bytecode),
    },
  },
};
