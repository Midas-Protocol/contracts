import { SALT } from "../../deploy/deploy";
import { ChainDeployConfig } from "../helpers";
import { ethers } from "ethers";
import { MasterPriceOracle } from "../../typechain";

export const deployConfig: ChainDeployConfig = {
  wtoken: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  nativeTokenName: "Ethereum (Local)",
  nativeTokenSymbol: "ETH",
  stableToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  wBTCToken: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
  blocksPerYear: 4 * 24 * 365 * 60,
  uniswap: {
    uniswapV2RouterAddress: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    uniswapV2FactoryAddress: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
    pairInitHashCode: ethers.utils.hexlify("0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"),
    hardcoded: [],
    uniswapData: [],
    uniswapOracleInitialDeployTokens: [],
  },
};

export const deploy = async ({ run, ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer, alice, bob } = await getNamedAccounts();

  ////
  //// TOKENS
  let dep = await deployments.deterministic("TRIBEToken", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [ethers.utils.parseEther("1250000000"), deployer],
    log: true,
  });
  const tribe = await dep.deploy();
  console.log("TRIBEToken: ", tribe.address);
  const tribeToken = await ethers.getContractAt("TRIBEToken", tribe.address, deployer);
  let tx = await tribeToken.transfer(alice, ethers.utils.parseEther("100000"), { from: deployer });
  await tx.wait();

  tx = await tribeToken.transfer(bob, ethers.utils.parseEther("100000"), { from: deployer });
  await tx.wait();
  dep = await deployments.deterministic("TOUCHToken", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [ethers.utils.parseEther("2250000000"), deployer],
    log: true,
  });
  const touch = await dep.deploy();
  const touchToken = await ethers.getContractAt("TOUCHToken", touch.address, deployer);
  tx = await touchToken.transfer(alice, ethers.utils.parseEther("100000"), { from: deployer });
  await tx.wait();

  tx = await touchToken.transfer(bob, ethers.utils.parseEther("100000"), { from: deployer });
  await tx.wait();
  ////

  ////
  //// ORACLES
  dep = await deployments.deterministic("SimplePriceOracle", {
    from: bob,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const simplePO = await dep.deploy();
  console.log("SimplePriceOracle: ", simplePO.address);

  const masterPriceOracle = (await ethers.getContract("MasterPriceOracle", deployer)) as MasterPriceOracle;
  const simplePriceOracle = await ethers.getContract("SimplePriceOracle", deployer);

  // get the ERC20 address of deployed cERC20
  const underlyings = [ethers.constants.AddressZero, tribe.address, touch.address];

  run("oracle:add-tokens", {
    underlyings: underlyings.join(","),
    oracles: Array(underlyings.length).fill(simplePriceOracle.address).join(","),
  });
  tx = await masterPriceOracle.setDefaultOracle(simplePriceOracle.address);
  await tx.wait();
  ////
};
