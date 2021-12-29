import { deployments, ethers, network } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
import { poolAssets } from "./setUp";
import { cERC20Conf, Fuse } from "../lib/esm";
import { getContractsConfig } from "./utilities";
import { BigNumber, utils } from "ethers";

use(solidity);

let deployedPoolAddress: string;

describe("FusePoolDirectory", function () {
  beforeEach(async function () {
    await deployments.fixture(); // ensure you start from a fresh deployments
  });

  describe("Deploy pool", async function () {
    it("should deploy the pool via contract", async function () {
      const { alice } = await ethers.getNamedSigners();
      const contractConfig = await getContractsConfig(network.name);

      const cpoFactory = await ethers.getContractFactory("ChainlinkPriceOracle", alice);
      const cpo = await cpoFactory.deploy([10]);

      const fpdWithSigner = await ethers.getContract("FusePoolDirectory", alice);

      // 50% -> 0.5 * 1e18
      const bigCloseFactor = utils.parseEther((50 / 100).toString());
      // 8% -> 1.08 * 1e8
      const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());
      const deployedPool = await fpdWithSigner.deployPool(
        "TEST",
        contractConfig.COMPOUND_CONTRACT_ADDRESSES.Comptroller,
        true,
        bigCloseFactor,
        bigLiquidationIncentive,
        cpo.address
      );
      expect(deployedPool).to.be.ok;
    });

    it.only("should deploy pool from sdk without whitelist", async function () {
      const { bob, alice } = await ethers.getNamedSigners();

      const spoFactory = await ethers.getContractFactory("ChainlinkPriceOracle", bob);
      const spo = await spoFactory.deploy([10]);

      const contractConfig = await getContractsConfig(network.name);
      const sdk = new Fuse(ethers.provider, contractConfig);

      // 50% -> 0.5 * 1e18
      const bigCloseFactor = utils.parseEther((50 / 100).toString());
      // 8% -> 1.08 * 1e8
      const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());

      const [poolAddress, implementationAddress, priceOracleAddress] = await sdk.deployPool(
        "TEST",
        false,
        bigCloseFactor,
        bigLiquidationIncentive,
        spo.address,
        {},
        { from: bob.address },
        [bob.address]
      );
      console.log(`Pool with address: ${poolAddress}, \noracle address: ${priceOracleAddress} deployed`);
      deployedPoolAddress = poolAddress;
      expect(poolAddress).to.be.ok;
      expect(implementationAddress).to.be.ok;

      const { comptroller, name: _unfiliteredName } = await sdk.contracts.FusePoolDirectory.pools(0);

      expect(_unfiliteredName).to.be.equal("TEST");

      const jrm = await ethers.getContract("JumpRateModel", bob);
      // const assets = poolAssets(jrm.address, implementationAddress);

      const ethConf: cERC20Conf = {
        underlying: "0x0000000000000000000000000000000000000000",
        comptroller: implementationAddress,
        interestRateModel: jrm.address,
        name: "Ethereum",
        symbol: "ETH",
        decimals: 8,
        admin: "true",
        collateralFactor: 75,
        reserveFactor: 20,
        adminFee: 10,
        bypassPriceFeedCheck: true,
        initialExchangeRateMantissa: utils.parseEther("0.1"),
      };
      const [cEtherDelegatorAddress, cEthImplAddr, receipt] = await sdk.deployCEther(
        ethConf,
        { from: bob.address },
        sdk.contractConfig.COMPOUND_CONTRACT_ADDRESSES.CEtherDelegate
          ? sdk.contractConfig.COMPOUND_CONTRACT_ADDRESSES.CEtherDelegate
          : null
      );
      console.log(cEtherDelegatorAddress, cEthImplAddr, receipt.status);
      // for (const assetConf of assets.assets) {
      //   const [assetAddress, cTokenImplementationAddress, irmModel, receipt] = await sdk.deployAsset(
      //     Fuse.JumpRateModelConf,
      //     assetConf,
      //     { from: bob.address }
      //   );
      //   console.log("-----------------");
      //   console.log("deployed asset: ", assetConf.name);
      //   console.log("Asset Address: ", assetAddress);
      //   console.log("irmModel: ", irmModel);
      //   console.log("Implementation Address: ", cTokenImplementationAddress);
      //   console.log("TX Receipt: ", receipt.transactionHash);
      //   console.log("-----------------");
      // }
      const t = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(implementationAddress);
      console.log(t, "pool summary for implementation: ", implementationAddress);
      const fusePoolData = await sdk.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(implementationAddress);

      console.log(fusePoolData, "FPD");
    });
  });
});
