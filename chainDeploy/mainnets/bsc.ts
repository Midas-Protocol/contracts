import { SALT } from "../../deploy/deploy";
import { ChainDeployConfig, ChainlinkFeedBaseCurrency, deployChainlinkOracle, deployUniswapOracle } from "../helpers";
import { ethers } from "ethers";
import { Asset, ChainDeployFnParams, ChainlinkAsset, CurvePoolConfig } from "../helpers/types";
import { deployCurveLpOracle } from "../oracles/curveLp";
import { deployUniswapLpOracle } from "../oracles/uniswapLp";

export const assets: Asset[] = [
  {
    symbol: "WBNB",
    underlying: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    name: "Wrapped Binance Network Token",
    decimals: 18,
  },
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
  // Bomb
  {
    symbol: "xBOMB",
    underlying: "0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b",
    name: "xBOMB",
    decimals: 18,
  },
  // Jarvis
  {
    symbol: "jBRL",
    underlying: "0x316622977073BBC3dF32E7d2A9B3c77596a0a603",
    name: "Jarvis Synthetic Brazilian Real",
    decimals: 18,
  },
];

export const deployConfig: ChainDeployConfig = {
  wtoken: assets.find((a) => a.symbol === "WBNB")!.underlying,
  nativeTokenUsdChainlinkFeed: "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE",
  nativeTokenName: "Binance Network Token",
  nativeTokenSymbol: "BNB",
  stableToken: assets.find((a) => a.symbol === "BUSD")!.underlying,
  wBTCToken: assets.find((a) => a.symbol === "BTCB")!.underlying,
  blocksPerYear: 20 * 24 * 365 * 60,
  uniswap: {
    hardcoded: [],
    uniswapData: [{ lpDisplayName: "PancakeSwap", lpName: "Pancake LPs", lpSymbol: "Cake-LP" }],
    pairInitHashCode: ethers.utils.hexlify("0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5"),
    uniswapV2RouterAddress: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
    uniswapV2FactoryAddress: "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73",
    uniswapOracleInitialDeployTokens: [
      {
        token: "0x522348779DCb2911539e76A1042aA922F9C47Ee3", // BOMB
        baseToken: "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c", // BTCB
      },
    ],
    uniswapOracleLpTokens: [
      "0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6", // LP,
    ],
  },
  plugins: [
    {
      // 0x
      strategy: "BeefyERC4626",
      name: "BOMB-BTC LP Token",
      underlying: "0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6", // BOMB-BTC LP
      symbol: "BOMB-BTC LP",
      otherParams: [
        "0x84392649eb0bC1c1532F2180E58Bae4E1dAbd8D6",
        "BOMB-BTCB LP",
        "BOMB-BTCB",
        "0x94e85b8e050f3f281cb9597cc0144f1f7af1fe9b",
      ],
    },
    {
      // 0x
      strategy: "BombERC4626",
      underlying: "0x522348779DCb2911539e76A1042aA922F9C47Ee3", // BOMB
      name: "BOMB",
      symbol: "BOMB",
      otherParams: ["0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b", "0x522348779DCb2911539e76A1042aA922F9C47Ee3"], // xBOMB, BOMB
    },
    {
      // 0x
      strategy: "EllipsisERC4626",
      underlying: "0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452", // 3EPS
      name: "Ellipsis.finance BUSD/USDC/USDT",
      symbol: "3EPS",
      otherParams: ["0xcce949De564fE60e7f96C85e55177F8B9E4CF61b",], // lpTokenStaker, dynamicFlywheel
    },
    {
      // 0x
      strategy: "EllipsisERC4626",
      underlying: "0x0BC3a8239B0a63E945Ea1bd6722Ba747b9557e56", // dai3EPS
      name: "Ellipsis.finance DAI/3EPS",
      symbol: "dai3EPS",
      otherParams: ["0xcce949De564fE60e7f96C85e55177F8B9E4CF61b",],// lpTokenStaker, dynamicFlywheel
    },
    {
      // 0x
      strategy: "EllipsisERC4626",
      underlying: "0x151F1611b2E304DEd36661f65506f9D7D172beba", // ust3EPS
      name: "Ellipsis.finance UST/3EPS",
      symbol: "ust3EPS",
      otherParams: ["0xcce949De564fE60e7f96C85e55177F8B9E4CF61b",],// lpTokenStaker, dynamicFlywheel
    },
    {
      // 0x
      strategy: "AutofarmERC4626",
      underlying: "", //
      name: "",
      symbol: "",
      otherParams: [],
    },
  ],
  dynamicFlywheels: [null, null, null, null],
};

const chainlinkAssets: ChainlinkAsset[] = [
  //
  {
    symbol: "BUSD",
    aggregator: "0xcBb98864Ef56E9042e7d2efef76141f15731B82f",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "BTCB",
    aggregator: "0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "DAI",
    aggregator: "0x132d3C0B1D2cEa0BC552588063bdBb210FDeecfA",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
  {
    symbol: "ETH",
    aggregator: "0x63D407F32Aa72E63C7209ce1c2F5dA40b3AaE726",
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
  // Jarvis
  {
    symbol: "jBRL",
    aggregator: "0x5cb1Cb3eA5FB46de1CE1D0F3BaDB3212e8d8eF48",
    feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
  },
];

// https://docs.ellipsis.finance/deployment-links
const curvePools: CurvePoolConfig[] = [
  {
    // 3EPS
    lpToken: assets.find((a) => a.symbol === "3EPS")!.underlying,
    pool: "0x160CAed03795365F3A589f10C379FfA7d75d4E76",
    underlyings: [
      assets.find((a) => a.symbol === "BUSD")!.underlying,
      assets.find((a) => a.symbol === "USDC")!.underlying,
      assets.find((a) => a.symbol === "USDT")!.underlying,
    ],
  },
  {
    // dai3EPS metapool
    lpToken: assets.find((a) => a.symbol === "dai3EPS")!.underlying,
    pool: "0xc6a752948627bECaB5474a10821Df73fF4771a49",
    underlyings: [
      assets.find((a) => a.symbol === "DAI")!.underlying,
      assets.find((a) => a.symbol === "3EPS")!.underlying,
    ],
  },
  {
    // UST metapool
    lpToken: assets.find((a) => a.symbol === "ust3EPS")!.underlying,
    pool: "0x780de1A0E4613da6b65ceF7F5FB63d14CbDcfB72",
    underlyings: [
      assets.find((a) => a.symbol === "UST")!.underlying,
      assets.find((a) => a.symbol === "3EPS")!.underlying,
    ],
  },
];

export const deploy = async ({ run, ethers, getNamedAccounts, deployments }: ChainDeployFnParams): Promise<void> => {
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

  await deployUniswapLpOracle({ run, ethers, getNamedAccounts, deployments, deployConfig });

  await deployCurveLpOracle({ run, ethers, getNamedAccounts, deployments, deployConfig, curvePools });

  let dep = await deployments.deterministic("SimplePriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const simplePO = await dep.deploy();
  if (simplePO.transactionHash) await ethers.provider.waitForTransaction(simplePO.transactionHash);
  console.log("SimplePriceOracle: ", simplePO.address);
  ////

  dep = await deployments.deterministic("UniswapLpTokenLiquidator", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const uniswapLpTokenLiquidator = await dep.deploy();
  if (uniswapLpTokenLiquidator.transactionHash) {
    await ethers.provider.waitForTransaction(uniswapLpTokenLiquidator.transactionHash);
  }
  console.log("UniswapLpTokenLiquidator: ", uniswapLpTokenLiquidator.address);

  //// Liquidator Redemption Strategies
  /// xBOMB->BOMB
  dep = await deployments.deterministic("XBombLiquidator", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const xbombLiquidator = await dep.deploy();
  if (xbombLiquidator.transactionHash) await ethers.provider.waitForTransaction(xbombLiquidator.transactionHash);
  console.log("XBombLiquidator: ", xbombLiquidator.address);

  /// jBRL->BUSD
  let synthereumLiquidityPoolAddress = "0x0fD8170Dc284CD558325029f6AEc1538c7d99f49";
  let expirationTime = 40 * 60; // period in which the liquidation tx is valid to be included in a block, in seconds
  dep = await deployments.deterministic("JarvisSynthereumLiquidator", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [synthereumLiquidityPoolAddress, expirationTime],
    log: true,
  });
  const jarvisSynthereumLiquidator = await dep.deploy();
  if (jarvisSynthereumLiquidator.transactionHash)
    await ethers.provider.waitForTransaction(jarvisSynthereumLiquidator.transactionHash);
  console.log("JarvisSynthereumLiquidator: ", jarvisSynthereumLiquidator.address);

  /// EPS
  const curveOracle = await ethers.getContract("CurveLpTokenPriceOracleNoRegistry", deployer);
  dep = await deployments.deterministic("CurveLpTokenLiquidatorNoRegistry", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployConfig.wtoken, curveOracle.address],
    log: true,
  });
  const curveLpTokenLiquidatorNoRegistry = await dep.deploy();
  if (curveLpTokenLiquidatorNoRegistry.transactionHash)
    await ethers.provider.waitForTransaction(curveLpTokenLiquidatorNoRegistry.transactionHash);
  console.log("CurveLpTokenLiquidatorNoRegistry: ", curveLpTokenLiquidatorNoRegistry.address);

  ////
};
