import { UniswapDeployFnParams } from "../helpers/types";

export const deployUniswapLpOracle = async ({
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
}: UniswapDeployFnParams): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  const lpToken = await deployments.deploy("UniswapLpTokenPriceOracle", {
    from: deployer,
    args: [deployConfig.wtoken],
    log: true,
  });
  if (lpToken.transactionHash) {
    await ethers.provider.waitForTransaction(lpToken.transactionHash);
  }
  console.log("UniswapLpTokenPriceOracle: ", lpToken.address);

  const mpo = await ethers.getContract("MasterPriceOracle", deployer);
  let tx = await mpo.add([deployConfig.uniswap.uniswapOracleLpTokens[0]], [lpToken.address]);
  await tx.wait();

  console.log(`Master Price Oracle updated for token ${deployConfig.uniswap.uniswapOracleLpTokens[0]}`);
};
