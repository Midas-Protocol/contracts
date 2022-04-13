import { SALT } from "../../deploy/deploy";
import { UniswapTwapPriceOracleV2Factory } from "../../typechain/UniswapTwapPriceOracleV2Factory";
import { constants } from "ethers";
import { UniswapDeployFnParams } from "./types";

export const deployUniswapOracle = async ({
  run,
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
}: UniswapDeployFnParams): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  const mpo = await ethers.getContract("MasterPriceOracle", deployer);
  const updateOracles = [],
    updateUnderlyings = [];
  //// Uniswap Oracle
  let dep = await deployments.deterministic("UniswapTwapPriceOracleV2", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const utpo = await dep.deploy();
  if (utpo.transactionHash) await ethers.provider.waitForTransaction(utpo.transactionHash);
  console.log("UniswapTwapPriceOracleV2: ", utpo.address);

  dep = await deployments.deterministic("UniswapTwapPriceOracleV2Root", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployConfig.wtoken],
    log: true,
  });
  const utpor = await dep.deploy();
  if (utpor.transactionHash) await ethers.provider.waitForTransaction(utpor.transactionHash);
  console.log("UniswapTwapPriceOracleV2Root: ", utpor.address);

  for (let tokenPair of deployConfig.uniswap.uniswapOracleInitialDeployTokens) {
    dep = await deployments.deterministic("UniswapTwapPriceOracleV2Factory", {
      from: deployer,
      salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
      args: [utpor.address, utpo.address, tokenPair.token],
      log: true,
    });
    const utpof = await dep.deploy();
    if (utpof.transactionHash) await ethers.provider.waitForTransaction(utpof.transactionHash);
    console.log("UniswapTwapPriceOracleV2Factory: ", utpof.address);

    const uniTwapOracleFactory = (await ethers.getContract(
      "UniswapTwapPriceOracleV2Factory",
      deployer
    )) as UniswapTwapPriceOracleV2Factory;

    const existingOracle = await uniTwapOracleFactory.callStatic.oracles(
      deployConfig.uniswap.uniswapV2FactoryAddress,
      deployConfig.wtoken
    );
    if (existingOracle == constants.AddressZero) {
      // deploy oracle with wtoken as base token
      let tx = await uniTwapOracleFactory.deploy(deployConfig.uniswap.uniswapV2FactoryAddress, deployConfig.wtoken);
      await tx.wait();
    } else {
      console.log("UniswapTwapPriceOracleV2 already deployed at: ", existingOracle);
    }

    let oldBaseTokenOracle = await uniTwapOracleFactory.callStatic.oracles(
      deployConfig.uniswap.uniswapV2FactoryAddress,
      tokenPair.baseToken
    );

    if (oldBaseTokenOracle == constants.AddressZero) {
      let tx = await uniTwapOracleFactory.deploy(deployConfig.uniswap.uniswapV2FactoryAddress, tokenPair.baseToken);
      await tx.wait();
      oldBaseTokenOracle = await uniTwapOracleFactory.callStatic.oracles(
        deployConfig.uniswap.uniswapV2FactoryAddress,
        tokenPair.baseToken
      );
    }

    const underlyingOracle = await mpo.callStatic.oracles(tokenPair.baseToken);
    if (underlyingOracle == constants.AddressZero || underlyingOracle != oldBaseTokenOracle) {
      updateOracles.push(oldBaseTokenOracle);
      updateUnderlyings.push(tokenPair.baseToken);
    }
  }

  if (updateOracles.length) {
    let tx = await mpo.add(updateUnderlyings, updateOracles);
    await tx.wait();
    console.log(`Master Price Oracle updated for tokens ${updateUnderlyings.join(", ")}`);
  }
};
