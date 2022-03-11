import { SALT } from "../../deploy/deploy";
import { constants, providers } from "ethers";
import { CurveLpFnParams } from "../helpers/types";

export const deployCurveLpOracle = async ({
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
  curvePools,
  run
}: CurveLpFnParams): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  let tx: providers.TransactionResponse;
  let receipt: providers.TransactionReceipt;

  //// CurveLpTokenPriceOracleNoRegistry
  let dep = await deployments.deterministic("CurveLpTokenPriceOracleNoRegistry", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const cpo = await dep.deploy();
  console.log("CurveLpTokenPriceOracleNoRegistry: ", cpo.address);

  const curveOracle = await ethers.getContract("CurveLpTokenPriceOracleNoRegistry", deployer);
  let owner = await curveOracle.owner();
  if (owner === constants.AddressZero) {
    tx = await curveOracle.initialize([], [], []);
    console.log("initialize tx sent: ", tx.hash);
    receipt = await tx.wait();
    console.log("registerPool mined: ", receipt.transactionHash);
  }

  for (const pool of curvePools) {
    const registered = await curveOracle.poolOf(pool.lpToken);
    if (registered !== constants.AddressZero) {
      console.log("Pool already registered", pool);
      continue;
    }
    tx = await curveOracle.registerPool(pool.lpToken, pool.pool, pool.underlyings);
    console.log("registerPool sent: ", tx.hash);
    receipt = await tx.wait();
    console.log("registerPool mined: ", receipt.transactionHash);
  }

  run("oracle:add-tokens", {
    underlyings: curvePools.map((c) => c.lpToken).join(","),
    oracles: Array(curvePools.length).fill(curveOracle.address).join(","),
  });
};
