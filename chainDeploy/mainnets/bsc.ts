import { SALT } from "../../deploy/deploy";
import { ChainDeployConfig, ChainlinkFeedBaseCurrency, deployChainlinkOracle, deployUniswapOracle } from "../helpers";
import { ethers } from "ethers";
import { Asset, ChainDeployFnParams, ChainlinkAsset, CurvePoolConfig } from "../helpers/types";
import { deployCurveLpOracle } from "../oracles/curveLp";

export const deployConfig: ChainDeployConfig = {
  wtoken: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
  nativeTokenUsdChainlinkFeed: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
  nativeTokenName: "Binance Network Token",
  nativeTokenSymbol: "BNB",
  stableToken: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
  wBTCToken: "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c",
  blocksPerYear: 20 * 24 * 365 * 60,
  uniswap: {
    hardcoded: [],
    uniswapData: [{ lpDisplayName: "PancakeSwap", lpName: "Pancake LPs", lpSymbol: "Cake-LP" }],
    pairInitHashCode: ethers.utils.hexlify("0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5"),
    uniswapV2RouterAddress: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
    uniswapV2FactoryAddress: "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73",
    uniswapOracleInitialDeployTokens: [
      "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56", // BUSD
      "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c", // BTCB
      "0x2170Ed0880ac9A755fd29B2688956BD959F933F8", // ETH
    ],
  },
};

export const assets: Asset[] = [
  {
    symbol: "BUSD",
    underlying: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
    name: "Binance USD",
    decimals: 18,
  },
  {
    symbol: "BTCB",
    underlying: "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c",
    name: "Binance BTC",
    decimals: 18,
  },
  {
    symbol: "DAI",
    underlying: "0x132d3C0B1D2cEa0BC552588063bdBb210FDeecfA",
    name: "Binance DAI",
    decimals: 18,
  },
  {
    symbol: "ETH",
    underlying: "0x2170Ed0880ac9A755fd29B2688956BD959F933F8",
    name: "Binance ETH",
    decimals: 18,
  },
  // STONX
  {
    symbol: "TSLA",
    underlying: "0xF215A127A196e3988C09d052e16BcFD365Cd7AA3",
    name: "Wrapped Mirror TSLA Token",
    decimals: 18,
  },
  {
    symbol: "GOOGL",
    underlying: "0x62D71B23bF15218C7d2D7E48DBbD9e9c650B173f",
    name: "Wrapped Mirror GOOGL Token",
    decimals: 18,
  },
  {
    symbol: "NFLX",
    underlying: "0xa04F060077D90Fe2647B61e4dA4aD1F97d6649dc",
    name: "Wrapped Mirror NFLX Token",
    decimals: 18,
  },
  {
    symbol: "AMZN",
    underlying: "0x3947B992DC0147D2D89dF0392213781b04B25075",
    name: "Wrapped Mirror AMZN Token",
    decimals: 18,
  },
  // CZ
  {
    symbol: "BETH",
    underlying: "0x250632378E573c6Be1AC2f97Fcdf00515d0Aa91B",
    name: "Binance Beacon ETH",
    decimals: 18,
  },
  {
    symbol: "CAKE",
    underlying: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
    name: "PancakeSwap Token",
    decimals: 18,
  },
  //
  {
    symbol: "AUTO",
    underlying: "0xa184088a740c695E156F91f5cC086a06bb78b827",
    name: "AUTOv2",
    decimals: 18,
  },
  {
    symbol: "BIFI",
    underlying: "0xCa3F508B8e4Dd382eE878A314789373D80A5190A",
    name: "beefy.finance",
    decimals: 18,
  },
  // stables
  {
    symbol: "BIFI",
    underlying: "0xCa3F508B8e4Dd382eE878A314789373D80A5190A",
    name: "beefy.finance",
    decimals: 18,
  },
  {
    symbol: "USDC",
    underlying: "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d",
    name: "Binance-Peg USD Coin",
    decimals: 18,
  },
  {
    symbol: "USDT",
    underlying: "0x55d398326f99059fF775485246999027B3197955",
    name: "Binance-Peg BSC-USD",
    decimals: 18,
  },
  {
    symbol: "UST",
    underlying: "0x23396cF899Ca06c4472205fC903bDB4de249D6fC",
    name: "Wrapped UST Token",
    decimals: 18,
  },
  // Ellipsis
  {
    symbol: "3EPS",
    underlying: "0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452",
    name: "Ellipsis.finance BUSD/USDC/USDT",
    decimals: 18,
  },
  {
    symbol: "dai3EPS",
    underlying: "0x0BC3a8239B0a63E945Ea1bd6722Ba747b9557e56",
    name: "Ellipsis.finance DAI/3EPS",
    decimals: 18,
  },
  {
    symbol: "ust3EPS",
    underlying: "0x151F1611b2E304DEd36661f65506f9D7D172beba",
    name: "Ellipsis.finance UST/3EPS",
    decimals: 18,
  },
];

const chainlinkAssets: ChainlinkAsset[] = [
  //
  {
    symbol: "BUSD",
    aggregator: "0xcBb98864Ef56E9042e7d2efef76141f15731B82f",
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
    aggregator: "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  // STONX
  {
    symbol: "TSLA",
    aggregator: "0xEEA2ae9c074E87596A85ABE698B2Afebc9B57893",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "GOOGL",
    aggregator: "0xeDA73F8acb669274B15A977Cb0cdA57a84F18c2a",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "AMZN",
    aggregator: "0x51d08ca89d3e8c12535BA8AEd33cDf2557ab5b2a",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  // CZ
  {
    symbol: "BETH",
    aggregator: "0x2A3796273d47c4eD363b361D3AEFb7F7E2A13782",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "CAKE",
    aggregator: "0xB6064eD41d4f67e353768aA239cA86f4F73665a1",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  //
  {
    symbol: "AUTO",
    aggregator: "0x88E71E6520E5aC75f5338F5F0c9DeD9d4f692cDA",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "BIFI",
    aggregator: "0xaB827b69daCd586A37E80A7d552a4395d576e645",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  // stables
  {
    symbol: "USDC",
    aggregator: "0x51597f405303C4377E36123cBc172b13269EA163",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "USDT",
    aggregator: "0xB97Ad0E74fa7d920791E90258A6E2085088b4320",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "UST",
    aggregator: "0xcbf8518F8727B8582B22837403cDabc53463D462",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
];

// https://docs.ellipsis.finance/deployment-links
const curvePools: CurvePoolConfig[] = [
  {
    // 3EPS
    lpToken: assets.find(a => a.symbol === "3EPS")!.underlying,
    pool: "0x160CAed03795365F3A589f10C379FfA7d75d4E76",
    underlyings: [
      assets.find(a => a.symbol === "BUSD")!.underlying,
      assets.find(a => a.symbol === "USDC")!.underlying,
      assets.find(a => a.symbol === "USDT")!.underlying,
    ],
  },
  {
    // dai3EPS metapool
    lpToken: assets.find(a => a.symbol === "dai3EPS")!.underlying,
    pool: "0xc6a752948627bECaB5474a10821Df73fF4771a49",
    underlyings: [
      assets.find(a => a.symbol === "DAI")!.underlying,
      assets.find(a => a.symbol === "3EPS")!.underlying,
    ],
  },
  {
    // UST metapool
    lpToken: assets.find(a => a.symbol === "ust3EPS")!.underlying,
    pool: "0x151F1611b2E304DEd36661f65506f9D7D172beba",
    underlyings: [
      assets.find(a => a.symbol === "UST")!.underlying,
      assets.find(a => a.symbol === "3EPS")!.underlying,
    ],
  },
];

export const deploy = async ({
  run,
  ethers,
  getNamedAccounts,
  deployments,
}: ChainDeployFnParams): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  ////
  //// ORACLES

  //// ChainLinkV2 Oracle
  await deployChainlinkOracle({
    run,
    ethers,
    getNamedAccounts,
    deployments,
    deployConfig,
    assets,
    chainlinkAssets,
  });
  ////

  //// Uniswap Oracle
  await deployUniswapOracle({ run, ethers, getNamedAccounts, deployments, deployConfig });
  ////

  await deployCurveLpOracle({ run, ethers, getNamedAccounts, deployments, deployConfig, curvePools })

  let dep = await deployments.deterministic("SimplePriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const simplePO = await dep.deploy();
  console.log("SimplePriceOracle: ", simplePO.address);
  ////
};
