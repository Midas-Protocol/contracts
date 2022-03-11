import { providers } from "ethers";
import { SALT } from "../../deploy/deploy";
import { ChainlinkPriceOracleV2 } from "../../typechain";
import { Asset, ChainlinkDeployFnParams, ChainlinkFeedBaseCurrency } from "./types";

export const deployChainlinkOracle = async ({
  run,
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
  assets,
  chainlinkAssets,
}: ChainlinkDeployFnParams): Promise<{ cpo: any; chainLinkv2: any }> => {
  const { deployer } = await getNamedAccounts();
  let tx: providers.TransactionResponse;

  //// Chainlink Oracle
  let dep = await deployments.deterministic("ChainlinkPriceOracleV2", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployer, true, deployConfig.wtoken, deployConfig.nativeTokenUsdChainlinkFeed],
    log: true,
  });
  const cpo = await dep.deploy();
  console.log("ChainlinkPriceOracleV2: ", cpo.address);

  const chainLinkv2 = (await ethers.getContract("ChainlinkPriceOracleV2", deployer)) as ChainlinkPriceOracleV2;
  tx = await chainLinkv2.setPriceFeeds(
    chainlinkAssets.map((c) => assets.find((a: Asset) => a.symbol === c.symbol).underlying),
    chainlinkAssets.map((c) => c.aggregator),
    ChainlinkFeedBaseCurrency.USD
  );
  console.log(`Set price feeds for ChainlinkPriceOracleV2: ${tx.hash}`);
  await tx.wait();
  console.log(`Set price feeds for ChainlinkPriceOracleV2 mined: ${tx.hash}`);

  const underlyings = chainlinkAssets.map((c) => assets.find((a) => a.symbol === c.symbol).underlying);
  const oracles = Array(chainlinkAssets.length).fill(chainLinkv2.address);

  const spo = await ethers.getContract("MasterPriceOracle", deployer);
  tx = await spo.add(underlyings, oracles);
  await tx.wait();

  console.log(`Master Price Oracle updated for tokens ${underlyings.join(", ")}`);

  return { cpo: cpo, chainLinkv2: chainLinkv2 };
};
