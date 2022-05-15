import { ethers, getChainId, run } from "hardhat";
import { BigNumber, constants, providers, utils } from "ethers";
import {
  CErc20,
  CEther,
  EIP20Interface,
  FuseFeeDistributor,
  FuseSafeLiquidator,
  MasterPriceOracle,
  SimplePriceOracle,
} from "../../typechain";
import { createPool, deployAssets, DeployedAsset, getPoolAssets } from "./pool";
import { expect } from "chai";
import { cERC20Conf, ChainLiquidationConfig, Fuse } from "../../";
import { getOrCreateFuse } from "./fuseSdk";

export const resetPriceOracle = async (erc20One, erc20Two) => {
  const chainId = parseInt(await getChainId());

  if (chainId !== 31337 && chainId !== 1337) {
    const { deployer } = await ethers.getNamedSigners();
    const sdk = new Fuse(ethers.provider, Number(chainId));
    const mpo = (await ethers.getContractAt(
      "MasterPriceOracle",
      sdk.oracles.MasterPriceOracle.address,
      deployer
    )) as MasterPriceOracle;
    const tx = await mpo.add(
      [erc20One.underlying, erc20Two.underlying],
      [sdk.chainDeployment.ChainlinkPriceOracleV2.address, sdk.chainDeployment.ChainlinkPriceOracleV2.address]
    );
    await tx.wait();
  }
};

export const setUpPriceOraclePrices = async (assets?: Array<string>) => {
  const chainId = parseInt(await getChainId());
  if (chainId === 31337 || chainId === 1337) {
    await setupLocalOraclePrices();
  } else if (chainId === 56) {
    await setUpBscOraclePrices(assets);
  }
};

const setupLocalOraclePrices = async () => {
  await run("oracle:set-price", { token: "TRIBE", price: "94.283240360313659894" });
  await run("oracle:set-price", { token: "TOUCH", price: "0.002673507105644885" });
};

const setUpBscOraclePrices = async (assets?: Array<string>) => {
  const { deployer } = await ethers.getNamedSigners();
  const sdk = await getOrCreateFuse();
  const spo = await ethers.getContractAt("SimplePriceOracle", sdk.oracles.SimplePriceOracle.address, deployer);
  const mpo = await ethers.getContractAt("MasterPriceOracle", sdk.oracles.MasterPriceOracle.address, deployer);
  const assetAddresses = assets ? assets : [constants.AddressZero];
  const oracleAddresses = Array(assetAddresses.length).fill(spo.address);
  let tx = await mpo.add(assetAddresses, oracleAddresses);
  await tx.wait();
  tx = await spo.setDirectPrice(constants.AddressZero, ethers.utils.parseEther("1"));
  await tx.wait();
};

export const getPositionRatio = async ({ name, namedUser, userAddress }) => {
  return await run("get-position-ratio", { name, namedUser, userAddress });
};

export const tradeNativeForAsset = async ({ token, amount, account }) => {
  await run("swap-wtoken-for-token", { token, amount, account });
};

export const tradeAssetForAsset = async ({ token1, token2, amount, account }) => {
  await run("swap-token-for-token", { token1, token2, amount, account });
};

export const setUpLiquidation = async ({ poolName }) => {
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
  let fuseFeeDistributor: FuseFeeDistributor;

  let ethCToken: CEther;
  let erc20OneCToken: CErc20;
  let erc20TwoCToken: CErc20;

  let erc20OneUnderlying: EIP20Interface;
  let erc20TwoUnderlying: EIP20Interface;

  let erc20OneOriginalUnderlyingPrice: BigNumber;
  let erc20TwoOriginalUnderlyingPrice: BigNumber;

  let tx: providers.TransactionResponse;

  const { bob, deployer, rando } = await ethers.getNamedSigners();

  const sdk = await getOrCreateFuse();

  simpleOracle = (await ethers.getContractAt(
    "SimplePriceOracle",
    sdk.oracles.SimplePriceOracle.address,
    deployer
  )) as SimplePriceOracle;
  oracle = (await ethers.getContractAt(
    "MasterPriceOracle",
    sdk.oracles.MasterPriceOracle.address,
    deployer
  )) as MasterPriceOracle;
  fuseFeeDistributor = (await ethers.getContractAt(
    "FuseFeeDistributor",
    sdk.contracts.FuseFeeDistributor.address,
    deployer
  )) as FuseFeeDistributor;

  liquidator = (await ethers.getContractAt(
    "FuseSafeLiquidator",
    sdk.contracts.FuseSafeLiquidator.address,
    rando
  )) as FuseSafeLiquidator;

  [poolAddress] = await createPool({ poolName, signer: deployer });
  const assets = await getPoolAssets(poolAddress, fuseFeeDistributor.address);

  erc20One = assets.assets.find((a) => a.underlying !== constants.AddressZero); // find first one

  expect(erc20One.underlying).to.be.ok;
  erc20Two = assets.assets.find((a) => a.underlying !== constants.AddressZero && a.underlying !== erc20One.underlying); // find second one

  expect(erc20Two.underlying).to.be.ok;
  eth = assets.assets.find((a) => a.underlying === constants.AddressZero);

  erc20OneOriginalUnderlyingPrice = await oracle.callStatic.price(erc20One.underlying);
  erc20TwoOriginalUnderlyingPrice = await oracle.callStatic.price(erc20Two.underlying);

  console.log("Setting up liquis with prices: ");
  console.log(`erc20One: ${erc20One.symbol}, price: ${ethers.utils.formatEther(erc20OneOriginalUnderlyingPrice)}`);
  console.log(`erc20Two: ${erc20Two.symbol}, price: ${ethers.utils.formatEther(erc20TwoOriginalUnderlyingPrice)}`);

  await oracle.add([erc20One.underlying, erc20Two.underlying], Array(2).fill(simpleOracle.address));

  tx = await simpleOracle.setDirectPrice(erc20One.underlying, erc20OneOriginalUnderlyingPrice);
  await tx.wait();

  tx = await simpleOracle.setDirectPrice(erc20Two.underlying, erc20TwoOriginalUnderlyingPrice);
  await tx.wait();

  const deployedAssets = await deployAssets(assets.assets.slice(0, 4), deployer);

  deployedEth = deployedAssets.find((a) => a.underlying === constants.AddressZero);
  deployedErc20One = deployedAssets.find((a) => a.underlying === erc20One.underlying);
  deployedErc20Two = deployedAssets.find((a) => a.underlying === erc20Two.underlying);

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
    erc20OneOriginalUnderlyingPrice,
    erc20TwoOriginalUnderlyingPrice,
    oracle,
    simpleOracle,
    fuseFeeDistributor,
  };
};

export const liquidateAndVerify = async (
  poolName: string,
  poolAddress: string,
  liquidatedUserName: string,
  liquidator: FuseSafeLiquidator,
  liquidationConfigOverrides: ChainLiquidationConfig,
  liquidatorBalanceCalculator: (address: string) => Promise<BigNumber>
) => {
  let tx: providers.TransactionResponse;

  const { rando } = await ethers.getNamedSigners();
  const sdk = await getOrCreateFuse();

  // Check balance before liquidation
  const ratioBefore = await getPositionRatio({
    name: poolName,
    userAddress: undefined,
    namedUser: liquidatedUserName,
  });
  console.log(`Ratio Before: ${ratioBefore}`);

  const liquidations = await sdk.getPotentialLiquidations([poolAddress]);
  expect(liquidations.length).to.eq(1);

  const desiredLiquidation = liquidations.filter((l) => l.comptroller === poolAddress)[0].liquidations[0];

  const liquidatorBalanceBeforeLiquidation = await liquidatorBalanceCalculator(rando.address);

  tx = await liquidator[desiredLiquidation.method](...desiredLiquidation.args, {
    value: desiredLiquidation.value,
  });
  await tx.wait();

  const receipt = await tx.wait();
  expect(receipt.status).to.eq(1);

  const ratioAfter = await getPositionRatio({
    name: poolName,
    userAddress: undefined,
    namedUser: liquidatedUserName,
  });
  console.log(`Ratio After: ${ratioAfter}`);
  expect(ratioBefore).to.be.gte(ratioAfter);

  // Assert balance after liquidation > balance before liquidation
  const liquidatorBalanceAfterLiquidation = await liquidatorBalanceCalculator(rando.address);

  console.log("Liquidator balance before liquidation: ", utils.formatEther(liquidatorBalanceBeforeLiquidation));
  console.log("Liquidator balance after liquidation: ", utils.formatEther(liquidatorBalanceAfterLiquidation));

  expect(liquidatorBalanceAfterLiquidation).gt(liquidatorBalanceBeforeLiquidation);
  expect(ratioBefore).to.be.gte(ratioAfter);
};
