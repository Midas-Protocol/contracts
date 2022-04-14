import { ChainDeployConfig, ChainlinkFeedBaseCurrency, deployChainlinkOracle, deployUniswapOracle } from "../helpers";
import { ethers } from "ethers";
import { Asset, ChainlinkAsset } from "../helpers/types";

export const deployConfig: ChainDeployConfig = {
  wtoken: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
  nativeTokenUsdChainlinkFeed: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
  nativeTokenName: "Binance Network Token (Testnet)",
  nativeTokenSymbol: "TBNB",
  stableToken: "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee",
  wBTCToken: "0x6ce8dA28E2f864420840cF74474eFf5fD80E65B8",
  blocksPerYear: 20 * 24 * 365 * 60,
  uniswap: {
    hardcoded: [],
    uniswapData: [],
    pairInitHashCode: ethers.utils.hexlify("0xd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66"),
    uniswapV2RouterAddress: "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    uniswapV2FactoryAddress: "0x6725F303b657a9451d8BA641348b6761A6CC7a17",
    uniswapOracleInitialDeployTokens: [
      {
        token: "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee",
        baseToken: "",
      }, // BUSD
      {
        token: "0x6ce8da28e2f864420840cf74474eff5fd80e65b8",
        baseToken: "",
      }, // BTCB
      {
        token: "0xd66c6B4F0be8CE5b39D52E0Fd1344c389929B378",
        baseToken: "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee",
      }, // ETH
    ],
  },
};

export const assets: Asset[] = [
  {
    symbol: "BUSD",
    underlying: "0xed24fc36d5ee211ea25a80239fb8c4cfd80f12ee",
    name: "Binance USD",
    decimals: 18,
  },
  {
    symbol: "BTCB",
    underlying: "0x6ce8da28e2f864420840cf74474eff5fd80e65b8",
    name: "Binance BTC",
    decimals: 18,
  },
  {
    symbol: "DAI",
    underlying: "0xEC5dCb5Dbf4B114C9d0F65BcCAb49EC54F6A0867",
    name: "Binance DAI",
    decimals: 18,
  },
  {
    symbol: "ETH",
    underlying: "0x76A20e5DC5721f5ddc9482af689ee12624E01313",
    name: "Binance ETH",
    decimals: 18,
  },
];

export const deploy = async ({ run, ethers, getNamedAccounts, deployments }): Promise<void> => {
  ////
  //// ORACLES
  const chainlinkAssets: ChainlinkAsset[] = [
    {
      symbol: "BUSD",
      aggregator: "0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "BTCB",
      aggregator: "0x5741306c21795FdCBb9b265Ea0255F499DFe515C",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "DAI",
      aggregator: "0xE4eE17114774713d2De0eC0f035d4F7665fc025D",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "ETH",
      aggregator: "0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
  ];

  //// ChainLinkV2 Oracle
  await deployChainlinkOracle({
    ethers,
    getNamedAccounts,
    deployments,
    deployConfig,
    assets,
    chainlinkAssets,
    run,
  });
  ////

  //// Uniswap Oracle
  await deployUniswapOracle({ run, ethers, getNamedAccounts, deployments, deployConfig });
  ////
};
