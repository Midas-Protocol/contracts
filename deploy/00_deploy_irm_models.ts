import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer } = await getNamedAccounts();

  //  https://etherscan.io/address/0xd956188795ca6F4A74092ddca33E0Ea4cA3a1395#code
  let dep = await deployments.deterministic("JumpRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [
      "20000000000000000", // baseRatePerYear
      "180000000000000000", // multiplierPerYear
      "4000000000000000000", //jumpMultiplierPerYear
      "800000000000000000", // kink
    ],
    log: true,
  });

  const jrm = await dep.deploy();
  console.log("JumpRateModel: ", jrm.address);

  // taken from WhitePaperInterestRateModel used for cETH
  // https://etherscan.io/address/0x0c3f8df27e1a00b47653fde878d68d35f00714c0#code
  dep = await deployments.deterministic("WhitePaperInterestRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [
      "20000000000000000", // baseRatePerYear
      "100000000000000000", // multiplierPerYear
    ],
    log: true,
  });

  const wprm = await dep.deploy();
  console.log("WhitePaperInterestRateModel: ", wprm.address);
};

func.tags = ["IRM"];
export default func;
