import { constants, providers } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";

import { ChainDeployConfig, chainDeployConfig } from "../chainDeploy";
import { deployIRMs } from "../chainDeploy/helpers";
import { deployFuseSafeLiquidator } from "../chainDeploy/helpers/liquidator";

export const SALT = "midascapital.xyz";

const func: DeployFunction = async ({ run, ethers, getNamedAccounts, deployments, getChainId }): Promise<void> => {
  const chainId = await getChainId();
  console.log("chainId: ", chainId);
  const { deployer } = await getNamedAccounts();
  console.log("deployer: ", deployer);

  if (!chainDeployConfig[chainId]) {
    throw new Error(`Config invalid for ${chainId}`);
  }
  const { config: chainDeployParams, deployFunc }: { config: ChainDeployConfig; deployFunc: any } =
    chainDeployConfig[chainId];
  console.log("chainDeployParams: ", chainDeployParams);

  ////
  //// COMPOUND CORE CONTRACTS
  let tx: providers.TransactionResponse;

  let dep = await deployments.deterministic("FuseFeeDistributor", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
    },
  });

  const ffd = await dep.deploy();
  console.log("FuseFeeDistributor: ", ffd.address);
  const fuseFeeDistributor = await ethers.getContract("FuseFeeDistributor", deployer);
  let owner = await fuseFeeDistributor.owner();
  if (owner === ethers.constants.AddressZero) {
    let tx = await fuseFeeDistributor.initialize(ethers.utils.parseEther("0.1"));
    await tx.wait();
    console.log("FuseFeeDistributor initialized", tx.hash);
  } else {
    console.log("FuseFeeDistributor already initialized");
  }

  tx = await fuseFeeDistributor._setPoolLimits(10, ethers.constants.MaxUint256, ethers.constants.MaxUint256);
  await tx.wait();
  console.log("FuseFeeDistributor pool limits set", tx.hash);

  dep = await deployments.deterministic("Comptroller", {
    contract: "Comptroller.sol:Comptroller",
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [ffd.address],
    log: true,
  });
  const comp = await dep.deploy();
  console.log("Comptroller.sol:Comptroller: ", comp.address);

  dep = await deployments.deterministic("CErc20Delegate", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const erc20Del = await dep.deploy();
  if (erc20Del.transactionHash) await ethers.provider.waitForTransaction(erc20Del.transactionHash);
  console.log("CErc20Delegate: ", erc20Del.address);

  dep = await deployments.deterministic("CErc20PluginDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const erc20PluginDel = await dep.deploy();
  if (erc20PluginDel.transactionHash) await ethers.provider.waitForTransaction(erc20PluginDel.transactionHash);
  console.log("CErc20PluginDelegate: ", erc20PluginDel.address);

  dep = await deployments.deterministic("CErc20PluginRewardsDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const erc20PluginRewardsDel = await dep.deploy();
  if (erc20PluginRewardsDel.transactionHash)
    await ethers.provider.waitForTransaction(erc20PluginRewardsDel.transactionHash);
  console.log("CErc20PluginRewardsDelegate: ", erc20PluginRewardsDel.address);

  dep = await deployments.deterministic("CEtherDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const ethDel = await dep.deploy();
  if (ethDel.transactionHash) await ethers.provider.waitForTransaction(ethDel.transactionHash);
  console.log("CEtherDelegate: ", ethDel.address);

  dep = await deployments.deterministic("RewardsDistributorDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const rewards = await dep.deploy();
  if (rewards.transactionHash) await ethers.provider.waitForTransaction(rewards.transactionHash);
  // const rewardsDistributorDelegate = await ethers.getContract("RewardsDistributorDelegate", deployer);
  // await rewardsDistributorDelegate.initialize(constants.AddressZero);
  console.log("RewardsDistributorDelegate: ", rewards.address);
  ////

  ////
  //// FUSE CORE CONTRACTS
  dep = await deployments.deterministic("FusePoolDirectory", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
    },
  });
  const fpd = await dep.deploy();
  if (fpd.transactionHash) await ethers.provider.waitForTransaction(fpd.transactionHash);
  console.log("FusePoolDirectory: ", fpd.address);
  const fusePoolDirectory = await ethers.getContract("FusePoolDirectory", deployer);
  owner = await fusePoolDirectory.owner();
  if (owner === ethers.constants.AddressZero) {
    tx = await fusePoolDirectory.initialize(false, []);
    await tx.wait();
    console.log("FusePoolDirectory initialized", tx.hash);
  } else {
    console.log("FusePoolDirectory already initialized");
  }

  const comptroller = await ethers.getContract("Comptroller", deployer);
  tx = await fuseFeeDistributor._editComptrollerImplementationWhitelist(
    [constants.AddressZero],
    [comptroller.address],
    [true]
  );
  await tx.wait();
  console.log("FuseFeeDistributor comptroller whitelist set", tx.hash);

  tx = await comptroller._toggleAutoImplementations(true);
  await tx.wait();
  console.log("Toggled comptroller AutoImplementation", tx.hash);

  const fplDeployment = await deployments.deploy("FusePoolLens", {
    from: deployer,
    log: true,
  });

  if (fplDeployment.transactionHash) await ethers.provider.waitForTransaction(fplDeployment.transactionHash);
  console.log("FusePoolLens: ", fplDeployment.address);
  const fusePoolLens = await ethers.getContract("FusePoolLens", deployer);
  let directory = await fusePoolLens.directory();
  if (directory === constants.AddressZero) {
    tx = await fusePoolLens.initialize(
      fusePoolDirectory.address,
      chainDeployParams.nativeTokenName,
      chainDeployParams.nativeTokenSymbol,
      chainDeployParams.uniswap.hardcoded.map((h) => h.address),
      chainDeployParams.uniswap.hardcoded.map((h) => h.name),
      chainDeployParams.uniswap.hardcoded.map((h) => h.symbol),
      chainDeployParams.uniswap.uniswapData.map((u) => u.lpName),
      chainDeployParams.uniswap.uniswapData.map((u) => u.lpSymbol),
      chainDeployParams.uniswap.uniswapData.map((u) => u.lpDisplayName)
    );
    await tx.wait();
    console.log("FusePoolLens initialized", tx.hash);
  } else {
    console.log("FusePoolLens already initialized");
  }

  dep = await deployments.deterministic("FusePoolLensSecondary", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
    },
  });
  const fpls = await dep.deploy();
  if (fpls.transactionHash) await ethers.provider.waitForTransaction(fpls.transactionHash);
  console.log("FusePoolLensSecondary: ", fpls.address);

  const fusePoolLensSecondary = await ethers.getContract("FusePoolLensSecondary", deployer);
  directory = await fusePoolLensSecondary.directory();
  if (directory === constants.AddressZero) {
    tx = await fusePoolLensSecondary.initialize(fusePoolDirectory.address);
    await tx.wait();
    console.log("FusePoolLensSecondary initialized", tx.hash);
  } else {
    console.log("FusePoolLensSecondary already initialized");
  }

  dep = await deployments.deterministic("FuseFlywheelLensRouter", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
    },
  });
  const fflrReceipt = await dep.deploy();
  if (fflrReceipt.transactionHash) await ethers.provider.waitForTransaction(fflrReceipt.transactionHash);
  console.log("FuseFlywheelLensRouter: ", fflrReceipt.address);

  const etherDelegate = await ethers.getContract("CEtherDelegate", deployer);
  const erc20Delegate = await ethers.getContract("CErc20Delegate", deployer);
  const erc20PluginDelegate = await ethers.getContract("CErc20PluginDelegate", deployer);
  const erc20PluginRewardsDelegate = await ethers.getContract("CErc20PluginRewardsDelegate", deployer);

  tx = await fuseFeeDistributor._editCEtherDelegateWhitelist(
    [constants.AddressZero],
    [etherDelegate.address],
    [false],
    [true]
  );

  let receipt = await tx.wait();
  console.log("Set whitelist for Ether Delegate with status:", receipt.status, tx.hash);

  tx = await fuseFeeDistributor._editCErc20DelegateWhitelist(
    [constants.AddressZero, constants.AddressZero, constants.AddressZero],
    [erc20Delegate.address, erc20PluginDelegate.address, erc20PluginRewardsDelegate.address],
    [false, false, false],
    [true, true, true]
  );
  receipt = await tx.wait();
  console.log("Set whitelist for ERC20 Delegate with status:", receipt.status);

  dep = await deployments.deterministic("InitializableClones", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const ic = await dep.deploy();
  if (ic.transactionHash) await ethers.provider.waitForTransaction(ic.transactionHash);
  console.log("InitializableClones: ", ic.address);
  ////

  ////
  //// ORACLES
  dep = await deployments.deterministic("FixedNativePriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const fixedNativePO = await dep.deploy();
  console.log("FixedNativePriceOracle: ", fixedNativePO.address);

  dep = await deployments.deterministic("MasterPriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });

  const masterPO = await dep.deploy();
  if (masterPO.transactionHash) await ethers.provider.waitForTransaction(masterPO.transactionHash);
  console.log("MasterPriceOracle: ", masterPO.address);

  const masterPriceOracle = await ethers.getContract("MasterPriceOracle", deployer);
  const admin = await masterPriceOracle.admin();

  // intialize with no assets
  if (admin === ethers.constants.AddressZero) {
    let tx = await masterPriceOracle.initialize(
      [constants.AddressZero],
      [fixedNativePO.address],
      constants.AddressZero,
      deployer,
      true,
      chainDeployParams.wtoken
    );
    await tx.wait();
    console.log("MasterPriceOracle initialized", tx.hash);
  } else {
    tx = await masterPriceOracle.add([constants.AddressZero], [fixedNativePO.address]);
    await tx.wait();
    console.log("MasterPriceOracle already initialized");
  }

  // dep = await deployments.deterministic("KeydonixUniswapTwapPriceOracle", {
  //   from: deployer,
  //   salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
  //   args: [],
  //   log: true,
  // });
  // const kPO = await dep.deploy();
  // console.log("Keydonix Price Oracle: ", kPO.address);
  // const keydonixPriceOracle = await ethers.getContract("KeydonixUniswapTwapPriceOracle", deployer);
  // if ((await keydonixPriceOracle.denominationToken()) == constants.AddressZero) {
  //   tx = await keydonixPriceOracle.initialize(
  //     chainDeployParams.uniswap.uniswapV2FactoryAddress, // uniswapFactory,
  //     chainDeployParams.wtoken, // denominationTokenAddress,
  //     chainDeployParams.wtoken, // wtoken
  //     3, // TODO min blocks back
  //     Math.max(chainDeployParams.blocksPerYear / (365 * 24 * 3), 255) // max blocks back = 20 mins back
  //   );
  //   await tx.wait();
  //   console.log("Keydonix Price Oracle initialized", tx.hash);
  // } else {
  //   console.log(`${await keydonixPriceOracle.denominationToken()}`);
  //   console.log("Keydonix Price Oracle already initialized");
  // }

  ////
  //// IRM MODELS
  await deployIRMs({ ethers, getNamedAccounts, deployments, deployConfig: chainDeployParams });
  ////

  //// Liquidator
  await deployFuseSafeLiquidator({ ethers, getNamedAccounts, deployments, deployConfig: chainDeployParams });
  ///

  ////
  //// CHAIN SPECIFIC DEPLOYMENT
  console.log("Running deployment for chain: ", chainId);
  if (deployFunc) {
    await deployFunc({ run, ethers, getNamedAccounts, deployments });
  }
  ////
};

func.tags = ["prod"];

export default func;
