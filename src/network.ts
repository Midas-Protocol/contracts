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

export const oracleConfig = (deployments, artifacts) => {
  return {
    1337: {
      MockPriceOracle: {
        artifact: artifacts.MockPriceOracle,
        address: deployments.MockPriceOracle.address,
      },
      MasterPriceOracle: {
        artifact: artifacts.MasterPriceOracle,
        address: deployments.MasterPriceOracle.address,
      },
      ChainlinkPriceOracleV2: {
        artifact: artifacts.ChainlinkPriceOracleV2,
        address: deployments.ChainlinkPriceOracleV2.address,
      },
    },
  };
};

export const irmConfig = (deployments, artifacts) => {
  return {
    JumpRateModel: {
      artifact: artifacts.JumpRateModel,
      address: deployments.JumpRateModel.address,
    },
    WhitePaperInterestRateModel: {
      artifact: artifacts.WhitePaperInterestRateModel,
      address: deployments.WhitePaperInterestRateModel.address,
    },
  };
};
