import { ChainDeployConfig } from "../helpers";
import { ethers, providers } from "ethers";
import { SALT } from "../../deploy/deploy";
import { Asset } from "../helpers/types";

export const deployConfig: ChainDeployConfig = {
  wtoken: "0xA30404AFB4c43D25542687BCF4367F59cc77b5d2",
  nativeTokenName: "Dev (Testnet)",
  nativeTokenSymbol: "DEV",
  blocksPerYear: 5 * 24 * 365 * 60, // 12 second blocks, 5 blocks per minute
  uniswap: {
    hardcoded: [],
    uniswapData: [],
    pairInitHashCode: ethers.utils.hexlify("0xd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66"),
    uniswapV2RouterAddress: "0xAA30eF758139ae4a7f798112902Bf6d65612045f",
    uniswapV2FactoryAddress: "0x049581aEB6Fe262727f290165C29BDAB065a1B68",
    uniswapOracleInitialDeployTokens: [],
  },
};

export const assets: Asset[] = [
  {
    symbol: "ETH",
    underlying: "0x8cbF5008fa8De192209c6A987D0b3C9c3c7586a6",
    name: "Ethereum Token",
    decimals: 18,
    simplePriceOracleAssetPrice: ethers.utils.parseEther("100"),
  },
  {
    symbol: "BUSD",
    underlying: "0xe7b932a60E7d0CD08804fB8a3038bCa6218a7Fa2",
    name: "Binance USD",
    decimals: 18,
    simplePriceOracleAssetPrice: ethers.utils.parseEther("0.1"),
  },
  {
    symbol: "USDC",
    underlying: "0x65C281140d15184de571333387BfCC5e8Fc7c8dc",
    name: "USDC Coin",
    decimals: 18,
    simplePriceOracleAssetPrice: ethers.utils.parseEther("0.1"),
  },
];

export const deploy = async ({ run, getNamedAccounts, deployments, ethers }): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  console.log("deployer: ", deployer);
  let tx: providers.TransactionResponse;
  let receipt: providers.TransactionReceipt;
  //// ORACLES
  //// Underlyings use SimplePriceOracle to hardcode the price
  let dep = await deployments.deterministic("SimplePriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const spo = await dep.deploy();
  if (spo.transactionHash) await ethers.provider.waitForTransaction(spo.transactionHash);
  console.log("SimplePriceOracle: ", spo.address);

  const mpoUnderlyings = [];
  const mpoOracles = [];

  for (const asset of assets) {
    const spoContract = await ethers.getContract("SimplePriceOracle", deployer);
    tx = await spoContract.setDirectPrice(asset.underlying, asset.simplePriceOracleAssetPrice);
    console.log("set underlying price tx sent: ", asset.underlying, tx.hash);
    receipt = await tx.wait();
    console.log("set underlying price tx mined: ", asset.underlying, receipt.transactionHash);
    mpoUnderlyings.push(asset.underlying);
    mpoOracles.push(spoContract.address);
  }

  const masterPriceOracle = await ethers.getContract("MasterPriceOracle", deployer);

  tx = await masterPriceOracle.add(mpoUnderlyings, mpoOracles);
  await tx.wait();

  console.log(`MasterPriceOracle updated for assets: ${mpoUnderlyings.join(",")}`);
};
