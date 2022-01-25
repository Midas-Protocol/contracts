export const chainSpecificAddresses = {
  1337: {
    DAI_POT: "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",
    DAI_JUG: "0x19c0976f590d67707e62397c87829d896dc0f1f1",
    USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    W_TOKEN: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    W_TOKEN_USD_CHAINLINK_PRICE_FEED: "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419", // use mainnet
  },
  97: {
    DAI_POT: "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",
    DAI_JUG: "0x19c0976f590d67707e62397c87829d896dc0f1f1",
    USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    W_TOKEN: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
    W_TOKEN_USD_CHAINLINK_PRICE_FEED: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
  },
  1: {
    DAI_POT: "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",
    DAI_JUG: "0x19c0976f590d67707e62397c87829d896dc0f1f1",
    USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    W_TOKEN: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    W_TOKEN_USD_CHAINLINK_PRICE_FEED: "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419",
  },
};

export const oracleConfig = (deployments, artifacts) => {
  return {
    1337: {
      MockPriceOracle: {
        artifact: artifacts.MockPriceOracle,
        address: deployments.MockPriceOracle?.address,
      },
      MasterPriceOracle: {
        artifact: artifacts.MasterPriceOracle,
        address: deployments.MasterPriceOracle.address,
      },
      ChainlinkPriceOracleV2: {
        artifact: artifacts.ChainlinkPriceOracleV2,
        address: deployments.ChainlinkPriceOracleV2?.address,
      },
    },
    97: {
      MasterPriceOracle: {
        artifact: artifacts.MasterPriceOracle,
        address: deployments.MasterPriceOracle.address,
      },
      ChainlinkPriceOracleV2: {
        artifact: artifacts.ChainlinkPriceOracleV2,
        address: deployments.ChainlinkPriceOracleV2?.address,
      },
      UniswapTwapPriceOracleV2: {
        artifact: artifacts.UniswapTwapPriceOracleV2,
        address: deployments.UniswapTwapPriceOracleV2.address,
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
