import MasterPriceOracleArtifact from "../artifacts/contracts/oracles/MasterPriceOracle.sol/MasterPriceOracle.json";
import MockPriceOracleArtifact from "../artifacts/contracts/oracles/MockPriceOracle.sol/MockPriceOracle.json";
import ChainlinkPriceOracleArtifact from "../artifacts/contracts/oracles/ChainlinkPriceOracle.sol/ChainlinkPriceOracle.json";

import JumpRateModelArtifact from "../artifacts/contracts/compound/JumpRateModel.sol/JumpRateModel.json";
import WhitePaperInterestRateModelArtifact from "../artifacts/contracts/compound/WhitePaperInterestRateModel.sol/WhitePaperInterestRateModel.json";

export const tokenAddresses = {
  1337: {
    DAI_POT: "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",
    DAI_JUG: "0x19c0976f590d67707e62397c87829d896dc0f1f1",
    USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    W_TOKEN: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
  },
  1: {
    DAI_POT: "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",
    DAI_JUG: "0x19c0976f590d67707e62397c87829d896dc0f1f1",
    USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    W_TOKEN: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
  },
};

export const oracleConfig = (deployments) => {
  return {
    1337: {
      MockPriceOracle: {
        artifact: MockPriceOracleArtifact,
        address: deployments.MockPriceOracle.address,
      },
      MasterPriceOracle: {
        artifact: MasterPriceOracleArtifact,
        address: deployments.MasterPriceOracle.address,
      },
      ChainlinkPriceOracle: {
        artifact: ChainlinkPriceOracleArtifact,
        address: deployments.ChainlinkPriceOracle.address,
      },
    },
  };
};

export const irmConfig = (deployments) => {
  return {
    JumpRateModel: {
      artifact: JumpRateModelArtifact,
      address: deployments.JumpRateModel.address,
    },
    WhitePaperInterestRateModel: {
      artifact: WhitePaperInterestRateModelArtifact,
      address: deployments.WhitePaperInterestRateModel.address,
    },
  };
};
