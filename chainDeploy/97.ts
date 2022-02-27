import { SALT } from "../deploy/deploy";
import { ChainDeployConfig, ChainlinkFeedBaseCurrency } from "./helper";
import { BigNumber } from "ethers";

export const deployConfig97: ChainDeployConfig = {
  wtoken: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
  nativeTokenUsdChainlinkFeed: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
  nativeTokenName: "Binance Network Token (Testnet)",
  nativeTokenSymbol: "TBNB",
  blocksPerYear: BigNumber.from((20 * 24 * 365 * 60).toString()),
};

export const deploy97 = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  ////
  //// IRM MODELS|
  let dep = await deployments.deterministic("JumpRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [
      deployConfig97.blocksPerYear,
      "20000000000000000", // baseRatePerYear
      "180000000000000000", // multiplierPerYear
      "4000000000000000000", //jumpMultiplierPerYear
      "800000000000000000", // kink
    ],
    log: true,
  });

  const jrm = await dep.deploy();
  console.log("JumpRateModel: ", jrm.address);

  // taken from WhitePaperInterestRateModel used for cETH
  // https://etherscan.io/address/0x0c3f8df27e1a00b47653fde878d68d35f00714c0#code
  dep = await deployments.deterministic("WhitePaperInterestRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [
      deployConfig97.blocksPerYear,
      "20000000000000000", // baseRatePerYear
      "100000000000000000", // multiplierPerYear
    ],
    log: true,
  });

  ////
  //// ORACLES
  const chainlinkMappingUsd = [
    {
      symbol: "BUSD",
      aggregator: "0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa",
      underlying: "0xed24fc36d5ee211ea25a80239fb8c4cfd80f12ee",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "BTC",
      aggregator: "0x5741306c21795FdCBb9b265Ea0255F499DFe515C",
      underlying: "0x6ce8da28e2f864420840cf74474eff5fd80e65b8",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "DAI",
      aggregator: "0xE4eE17114774713d2De0eC0f035d4F7665fc025D",
      underlying: "0xEC5dCb5Dbf4B114C9d0F65BcCAb49EC54F6A0867",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "ETH",
      aggregator: "0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7",
      underlying: "0x76A20e5DC5721f5ddc9482af689ee12624E01313",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
  ];

  dep = await deployments.deterministic("ChainlinkPriceOracleV2", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployer, true, deployConfig97.wtoken, deployConfig97.nativeTokenUsdChainlinkFeed],
    log: true,
  });
  const cpo = await dep.deploy();
  console.log("ChainlinkPriceOracleV2: ", cpo.address);

  const chainLinkv2 = await ethers.getContract("ChainlinkPriceOracleV2", deployer);
  await chainLinkv2.setPriceFeeds(
    chainlinkMappingUsd.map((c) => c.underlying),
    chainlinkMappingUsd.map((c) => c.aggregator),
    ChainlinkFeedBaseCurrency.USD
  );

  const masterPriceOracle = await ethers.getContract("MasterPriceOracle", deployer);
  const admin = await masterPriceOracle.admin();
  if (admin === ethers.constants.AddressZero) {
    let tx = await masterPriceOracle.initialize(
      chainlinkMappingUsd.map((c) => c.underlying),
      Array(chainlinkMappingUsd.length).fill(chainLinkv2.address),
      cpo.address,
      deployer,
      true,
      deployConfig97.wtoken
    );
    await tx.wait();
    console.log("MasterPriceOracle initialized", tx.hash);
  } else {
    console.log("MasterPriceOracle already initialized");
  }
  dep = await deployments.deterministic("UniswapTwapPriceOracleV2Root", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployConfig97.wtoken],
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
    args: [utpor.address, utpo.address, deployConfig97.wtoken],
    log: true,
  });
  const utpof = await dep.deploy();
  console.log("UniswapTwapPriceOracleV2Factory: ", utpof.address);
  ////
};
