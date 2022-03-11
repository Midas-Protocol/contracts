import { deployments, ethers } from "hardhat";
import { assets as bscAssets } from "../../chainDeploy/mainnets/bsc";
import { constants, providers, utils } from "ethers";
import {
  CErc20,
  CEther,
  EIP20Interface,
  FuseSafeLiquidator,
  MasterPriceOracle,
  SimplePriceOracle,
} from "../../typechain";
import { createPool, deployAssets, DeployedAsset, getPoolAssets } from "./pool";
import { expect } from "chai";
import { cERC20Conf } from "../../dist/esm/src";

export const setUpPriceOraclePrices = deployments.createFixture(async ({ run, getChainId }, options) => {
  const chainId = parseInt(await getChainId());
  if (chainId === 31337 || chainId === 1337) {
    await setupLocalOraclePrices();
  } else if (chainId === 56) {
    await setUpBscOraclePrices();
  }
});

const setupLocalOraclePrices = deployments.createFixture(async ({ run }, options) => {
  await run("oracle:set-price", { token: "ETH", price: "1" });
  await run("oracle:set-price", { token: "TOUCH", price: "0.1" });
  await run("oracle:set-price", { token: "TRIBE", price: "0.2" });
});

const setUpBscOraclePrices = deployments.createFixture(async ({ run }, options) => {
  const { deployer } = await ethers.getNamedSigners();
  const oracle = await ethers.getContract("SimplePriceOracle", deployer);

  for (const asset of bscAssets) {
    await run("oracle:add-tokens", { underlyings: asset.underlying, oracles: oracle.address });
    await run("oracle:set-price", { address: asset.underlying, price: "1" });
  }
  await run("oracle:add-tokens", { underlyings: constants.AddressZero, oracles: oracle.address });
  await run("oracle:set-price", { address: constants.AddressZero, price: "1" });
});

export const getPositionRatio = deployments.createFixture(async ({ run }, { name, namedUser, userAddress, cgId }) => {
  return await run("get-position-ratio", { name, namedUser, userAddress, cgId });
});

export const tradeNativeForAsset = deployments.createFixture(async ({ run }, { token, amount, account }) => {
  await run("swap-wtoken-for-token", { token, amount, account });
});

export const setUpLiquidation = deployments.createFixture(async ({ run }, options) => {
  let eth: cERC20Conf;
  let erc20One: cERC20Conf;
  let erc20Two: cERC20Conf;

  let deployedEth: DeployedAsset;
  let deployedErc20One: DeployedAsset;
  let deployedErc20Two: DeployedAsset;

  let poolAddress: string;
  let simpleOracle: SimplePriceOracle;
  let oracle: MasterPriceOracle;
  let liquidator: FuseSafeLiquidator;

  let ethCToken: CEther;
  let erc20OneCToken: CErc20;
  let erc20TwoCToken: CErc20;

  let erc20OneUnderlying: EIP20Interface;
  let erc20TwoUnderlying: EIP20Interface;
  let tx: providers.TransactionResponse;

  const { bob, deployer } = await ethers.getNamedSigners();
  const poolName = "testing";

  await setUpPriceOraclePrices();
  simpleOracle = (await ethers.getContract("SimplePriceOracle", deployer)) as SimplePriceOracle;
  oracle = (await ethers.getContract("MasterPriceOracle", deployer)) as MasterPriceOracle;

  [poolAddress] = await createPool({ poolName });
  const assets = await getPoolAssets(poolAddress, (await ethers.getContract("FuseFeeDistributor")).address);

  erc20One = assets.assets.find((a) => a.underlying !== constants.AddressZero); // find first one

  expect(erc20One.underlying).to.be.ok;
  erc20Two = assets.assets.find((a) => a.underlying !== constants.AddressZero && a.underlying !== erc20One.underlying); // find second one

  expect(erc20Two.underlying).to.be.ok;
  eth = assets.assets.find((a) => a.underlying === constants.AddressZero);

  await oracle.add([eth.underlying, erc20One.underlying, erc20Two.underlying], Array(3).fill(simpleOracle.address));

  tx = await simpleOracle.setDirectPrice(eth.underlying, utils.parseEther("1"));
  await tx.wait();

  tx = await simpleOracle.setDirectPrice(erc20One.underlying, utils.parseEther("10"));
  await tx.wait();

  tx = await simpleOracle.setDirectPrice(erc20Two.underlying, utils.parseEther("0.0001"));
  await tx.wait();

  const deployedAssets = await deployAssets(assets.assets, bob);

  deployedEth = deployedAssets.find((a) => a.underlying === constants.AddressZero);
  deployedErc20One = deployedAssets.find((a) => a.underlying === erc20One.underlying);
  deployedErc20Two = deployedAssets.find((a) => a.underlying === erc20Two.underlying);

  liquidator = (await ethers.getContract("FuseSafeLiquidator", deployer)) as FuseSafeLiquidator;

  ethCToken = (await ethers.getContractAt("CEther", deployedEth.assetAddress)) as CEther;
  erc20OneCToken = (await ethers.getContractAt("CErc20", deployedErc20One.assetAddress)) as CErc20;
  erc20TwoCToken = (await ethers.getContractAt("CErc20", deployedErc20Two.assetAddress)) as CErc20;

  erc20TwoUnderlying = (await ethers.getContractAt("EIP20Interface", erc20Two.underlying)) as EIP20Interface;
  erc20OneUnderlying = (await ethers.getContractAt("EIP20Interface", erc20One.underlying)) as EIP20Interface;

  return {
    poolAddress,
    deployedEth,
    deployedErc20One,
    deployedErc20Two,
    eth,
    erc20One,
    erc20Two,
    ethCToken,
    erc20OneCToken,
    erc20TwoCToken,
    liquidator,
    erc20OneUnderlying,
    erc20TwoUnderlying,
    simpleOracle,
  };
});
