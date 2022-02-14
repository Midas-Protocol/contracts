import { task } from "hardhat/config";
import { expect } from "chai";

const UnhealthyPoolTypes = {
  TokenBorrowEthCollateral: {
    name: "unhealthy-token-borrow-eth-collateral",
    debtToken: "TOUCH",
  },
  EthBorrowTokenCollateral: {
    name: "unhealthy-eth-borrow-token-collateral",
    debtToken: "ETH",
  },
  TokenBorrowTokenCollateral: {
    name: "unhealthy-token-borrow-token-collateral",
    debtToken: "TOUCH",
  },
};

const UNHEALTHY_POOLS = [
  UnhealthyPoolTypes.TokenBorrowTokenCollateral,
  UnhealthyPoolTypes.TokenBorrowEthCollateral,
  UnhealthyPoolTypes.EthBorrowTokenCollateral,
];

export default task("e2e:unhealthy-pools-exist", "Get pools data").setAction(async (taskArgs, hre) => {
  for (const pool of UNHEALTHY_POOLS) {
    const ratio = await hre.run("get-position-ratio", { name: pool.name, namedUser: "deployer" });
    expect(ratio).to.be.gt(100);
  }
});

task("e2e:unhealthy-pools-became-healthy", "e2e: check pools are healthy").setAction(async (taskArgs, hre) => {
  for (const pool of UNHEALTHY_POOLS) {
    const ratio = await hre.run("get-position-ratio", { name: pool.name, namedUser: "deployer" });
    expect(ratio).to.be.lte(100);
  }
});

task("e2e:admin-fees-are-seized", "e2e: check fees are seized").setAction(async (taskArgs, hre) => {
  const sdkModule = await import("../lib/esm/src");
  const poolModule = await import("../test/utils/pool");

  const chainId = parseInt(await hre.getChainId());
  if (!(chainId in sdkModule.SupportedChains)) {
    throw "Invalid chain provided";
  }
  const sdk = new sdkModule.Fuse(hre.ethers.provider, chainId);
  for (const pool of UNHEALTHY_POOLS) {
    console.log(pool);
    console.log(pool.debtToken, "DEBBEBEBEB");
    const poolData = await poolModule.getPoolByName(pool.name, sdk);
    console.log(poolData);
    const poolAsset = poolData.assets.filter((a) => a.underlyingSymbol === pool.debtToken)[0];
    console.log(poolAsset);
    const assetCtoken = await hre.ethers.getContractAt(
      pool.debtToken === "ETH" ? "CEther" : "CErc20",
      poolAsset.cToken
    );
    const feesAfterLiquidation = await assetCtoken.totalFuseFees();
    console.log(
      `Fees for ${poolAsset.underlyingSymbol} (cToken: ${poolAsset.cToken}): ${hre.ethers.utils.formatEther(
        feesAfterLiquidation
      )}`
    );
    expect(feesAfterLiquidation).to.be.gt(hre.ethers.BigNumber.from(0));
  }
});
