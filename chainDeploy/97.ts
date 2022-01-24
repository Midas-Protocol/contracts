import { ChainlinkFeedBaseCurrency } from "./helper";

export const deploy97 = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  ////
  //// ORACLES
  const chainlinkMappingUsd = [
    {
      symbol: "AAVE",
      aggregator: "0x298619601ebCd58d0b526963Deb2365B485Edc74",
      underlying: "0xa372425353a7b94629eae6ad2b2167bd187ad971",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "BUSD",
      aggregator: "0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa",
      underlying: "0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
    {
      symbol: "CAKE",
      aggregator: "0x81faeDDfeBc2F8Ac524327d70Cf913001732224C",
      underlying: "0xf73D010412Fb5835C310728F0Ba1b7DFDe88379A",
      feedBaseCurrency: ChainlinkFeedBaseCurrency.USD,
    },
  ];

  let dep = await deployments.deterministic("ChainlinkPriceOracleV2", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [deployer, true, "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526"],
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

  let tx = await masterPriceOracle.add(
    chainlinkMappingUsd.map((c) => c.underlying),
    Array(chainlinkMappingUsd.length).fill(chainLinkv2.address)
  );
  await tx.wait();
  console.log("Added oracles to MasterPriceOracle for chain 97");
  ////
};
