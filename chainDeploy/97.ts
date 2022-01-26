import { ChainlinkFeedBaseCurrency } from "./helper";

export const deploy97 = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  ////
  //// ORACLES
  const chainlinkMappingUsd = [
    {
      symbol: "BUSD",
      aggregator: "0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa",
      underlying: "0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47",
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
    }
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
