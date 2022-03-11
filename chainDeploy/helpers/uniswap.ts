import { SALT } from "../../deploy/deploy";
import { UniswapTwapPriceOracleV2Factory } from "../../typechain";
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
  //// Uniswap Oracle
  let dep = await deployments.deterministic("UniswapTwapPriceOracleV2Root", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployConfig.wtoken],
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
    args: [utpor.address, utpo.address, deployConfig.wtoken],
    log: true,
  });
  const utpof = await dep.deploy();
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

    const nativeOracle = await uniTwapOracleFactory.callStatic.oracles(
      deployConfig.uniswap.uniswapV2FactoryAddress,
      deployConfig.wtoken
    );

    const underlyings = deployConfig.uniswap.uniswapOracleInitialDeployTokens.join(",");
    const oracles = Array(deployConfig.uniswap.uniswapOracleInitialDeployTokens.length).fill(nativeOracle).join(",");

    console.log(underlyings, oracles, "underlyings, oracles");

    run("oracle:add-tokens", { underlyings, oracles });

    console.log(
      "UniswapTwapPriceOracleV2 oracle deployed",
      tx.hash,
      "address: ",
      nativeOracle,
      "tokens: ",
      underlyings
    );
  } else {
    console.log("UniswapTwapPriceOracleV2 already deployed at: ", existingOracle);
  }
};
