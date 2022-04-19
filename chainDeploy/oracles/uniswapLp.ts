import { SALT } from "../../deploy/deploy";
import { UniswapDeployFnParams } from "../helpers/types";

export const deployUniswapLpOracle = async ({
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
  run,
}: UniswapDeployFnParams): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  let dep = await deployments.deterministic("UniswapLpTokenPriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [deployConfig.uniswap.uniswapOracleLpTokens[0].baseToken],
    log: true,
  });
  const lpToken = await dep.deploy();
  if (lpToken.transactionHash) await ethers.provider.waitForTransaction(lpToken.transactionHash);
  console.log("UniswapLpTokenPriceOracle: ", lpToken.address);

  const mpo = await ethers.getContract("MasterPriceOracle", deployer);
  let tx = await mpo.add([deployConfig.uniswap.uniswapOracleLpTokens[0].lpToken], [lpToken.address]);
  await tx.wait();

  console.log(`Master Price Oracle updated for token ${deployConfig.uniswap.uniswapOracleLpTokens[0].lpToken}`);
};
