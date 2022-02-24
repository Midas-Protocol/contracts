import { SALT } from "../deploy/deploy";
import { ChainDeployConfig, ChainlinkFeedBaseCurrency } from "./helper";

export const deployConfig: ChainDeployConfig = {
  wtoken: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
  nativeTokenUsdChainlinkFeed: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
  nativeTokenName: "Binance Network Token",
  nativeTokenSymbol: "BNB",
};

export const assets = [
  {
    symbol: "BUSD",
    underlying: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
    name: "Binance USD",
    decimals: 18,
  },
  {
    symbol: "BTC",
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
];

export const deploy = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer } = await getNamedAccounts();

  ////
  //// ORACLES
  const chainlinkMappingUsd = [
    {
      symbol: "BUSD",
      aggregator: "0xcBb98864Ef56E9042e7d2efef76141f15731B82f",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "BTC",
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
  ];

  let dep = await deployments.deterministic("ChainlinkPriceOracleV2", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployer, true, deployConfig.wtoken, deployConfig.nativeTokenUsdChainlinkFeed],
    log: true,
  });
  const cpo = await dep.deploy();
  console.log("ChainlinkPriceOracleV2: ", cpo.address);

  const chainLinkv2 = await ethers.getContract("ChainlinkPriceOracleV2", deployer);
  await chainLinkv2.setPriceFeeds(
    chainlinkMappingUsd.map((c) => assets.find((a) => a.symbol === c.symbol).underlying),
    chainlinkMappingUsd.map((c) => c.aggregator),
    ChainlinkFeedBaseCurrency.USD
  );

  const masterPriceOracle = await ethers.getContract("MasterPriceOracle", deployer);
  const admin = await masterPriceOracle.admin();
  if (admin === ethers.constants.AddressZero) {
    let tx = await masterPriceOracle.initialize(
      chainlinkMappingUsd.map((c) => assets.find((a) => a.symbol === c.symbol).underlying),
      Array(chainlinkMappingUsd.length).fill(chainLinkv2.address),
      cpo.address,
      deployer,
      true,
      deployConfig.wtoken
    );
    await tx.wait();
    console.log("MasterPriceOracle initialized", tx.hash);
  } else {
    console.log("MasterPriceOracle already initialized");
  }
  dep = await deployments.deterministic("UniswapTwapPriceOracleV2Root", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployConfig.wtoken],
    log: true,
  });
  const utpor = await dep.deploy();
  console.log("UniswapTwapPriceOracleV2Root: ", utpor.address);

  dep = await deployments.deterministic("UniswapTwapPriceOracleV2", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const utpo = await dep.deploy();
  console.log("UniswapTwapPriceOracleV2: ", utpo.address);

  dep = await deployments.deterministic("UniswapTwapPriceOracleV2Factory", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [utpor.address, utpo.address, deployConfig.wtoken],
    log: true,
  });
  const utpof = await dep.deploy();
  console.log("UniswapTwapPriceOracleV2Factory: ", utpof.address);

  dep = await deployments.deterministic("SimplePriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const simplePO = await dep.deploy();
  console.log("SimplePriceOracle: ", simplePO.address);
  ////
};
