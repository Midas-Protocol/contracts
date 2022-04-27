import { constants } from "ethers";
import { UniswapDeployFnParams } from "../helpers/types";

export const deployUniswapLpOracle = async ({
  ethers,
  getNamedAccounts,
  deployments,
  deployConfig,
}: UniswapDeployFnParams): Promise<void> => {
  const { deployer } = await getNamedAccounts();
  const lpTokenPriceOralce = await deployments.deploy("UniswapLpTokenPriceOracle", {
    from: deployer,
    args: [deployConfig.wtoken],
    log: true,
    waitConfirmations: 1,
  });
  console.log("UniswapLpTokenPriceOracle: ", lpTokenPriceOralce.address);

  const mpo = await ethers.getContract("MasterPriceOracle", deployer);
  let oracles = [];
  let underlyings = [];
  for (let lpToken of deployConfig.uniswap.uniswapOracleLpTokens) {
    if ((await mpo.oracles(lpToken)) === constants.AddressZero) {
      oracles.push(lpTokenPriceOralce.address);
      underlyings.push(lpToken);
    }
  }

  if (underlyings.length) {
    let tx = await mpo.add(underlyings, oracles);
    await tx.wait();
    console.log(`Master Price Oracle updated for token ${underlyings.join(",")}`);
  }
};
