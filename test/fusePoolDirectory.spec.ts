import { deployments, ethers, network } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
import { poolAssets } from "./setUp";
import { cERC20Conf, Fuse } from "../lib/esm";
import { ETH_ZERO_ADDRESS, getContractsConfig } from "./utilities";
import { BigNumber, constants, utils } from "ethers";
import { TransactionReceipt } from "@ethersproject/abstract-provider";

use(solidity);

describe("FusePoolDirectory", function () {
  beforeEach(async function () {
    await deployments.fixture(); // ensure you start from a fresh deployments
  });

  describe("Deploy pool", async function () {
    it("should decode", async function () {
      const abiCoder = new utils.AbiCoder();
      const constructorData = abiCoder.decode(
        ["address", "address", "string", "string", "address", "bytes", "uint256", "uint256"],
        "0x0000000000000000000000002a183d878ccdc00c0d20db9cbea033f11d5adf6a000000000000000000000000071ab319d920b2a9110dbd53546fa0ed8c612f6c0000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000014000000000000000000000000023df7c0f61f9d82dddadf53c7b1c09112f070fcd000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000071afd498d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008457468657265756d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003455448000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000"
      );
      console.log("constructorData: ", constructorData);
    });

    it("should deploy the pool via contract", async function () {
      this.timeout(120_000);
      const { alice } = await ethers.getNamedSigners();
      console.log("alice: ", alice.address);

      const cpoFactory = await ethers.getContractFactory("ChainlinkPriceOracle", alice);
      const cpo = await cpoFactory.deploy([10]);

      const fpdWithSigner = await ethers.getContract("FusePoolDirectory", alice);
      const implementationComptroller = await ethers.getContract("Comptroller");

      //// DEPLOY POOL
      const bigCloseFactor = utils.parseEther((50 / 100).toString());
      const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());
      const deployedPool = await fpdWithSigner.deployPool(
        "TEST",
        implementationComptroller.address,
        true,
        bigCloseFactor,
        bigLiquidationIncentive,
        cpo.address
      );
      expect(deployedPool).to.be.ok;
      const depReceipt = await deployedPool.wait();
      console.log("Deployed pool");

      // Confirm Unitroller address
      const saltsHash = utils.solidityKeccak256(
        ["address", "string", "uint"],
        [alice.address, "TEST", depReceipt.blockNumber]
      );
      const byteCodeHash = utils.keccak256((await deployments.getArtifact("Unitroller")).bytecode);
      let poolAddress = utils.getCreate2Address(fpdWithSigner.address, saltsHash, byteCodeHash);
      console.log("poolAddress: ", poolAddress);

      const pools = await fpdWithSigner.getPoolsByAccount(alice.address);
      const pool = pools[1][0];
      expect(pool.comptroller).to.eq(poolAddress);

      const contractConfig = await getContractsConfig(network.name);
      const sdk = new Fuse(ethers.provider, contractConfig);
      const { comptroller, name: _unfiliteredName } = await sdk.contracts.FusePoolDirectory.pools(0);

      expect(comptroller).to.eq(pool.comptroller);
      expect(_unfiliteredName).to.eq("TEST");

      const unitroller = await ethers.getContractAt("Unitroller", poolAddress, alice);
      const adminTx = await unitroller._acceptAdmin();
      await adminTx.wait();

      const comptrollerContract = await ethers.getContractAt("Comptroller", comptroller, alice);
      const admin = await comptrollerContract.admin();
      expect(admin).to.eq(alice.address);

      //// DEPLOY ASSETS
      const jrm = await ethers.getContract("JumpRateModel", alice);

      const ethConf: cERC20Conf = {
        underlying: "0x0000000000000000000000000000000000000000",
        comptroller: comptroller,
        interestRateModel: jrm.address,
        name: "Ethereum",
        symbol: "ETH",
        decimals: 8,
        admin: "true",
        collateralFactor: 0.75,
        reserveFactor: 0.2,
        adminFee: 0,
        bypassPriceFeedCheck: true,
        initialExchangeRateMantissa: constants.One,
      };
      const delegate = await ethers.getContract("CEtherDelegate", alice);
      const reserveFactorBN = utils.parseUnits((ethConf.reserveFactor / 100).toString());
      const adminFeeBN = utils.parseUnits((ethConf.adminFee / 100).toString());
      const collateralFactorBN = utils.parseUnits((ethConf.collateralFactor / 100).toString());

      let deployArgs = [
        ethConf.comptroller,
        ethConf.interestRateModel,
        ethConf.name,
        ethConf.symbol,
        delegate.address,
        "0x00",
        reserveFactorBN,
        adminFeeBN,
      ];
      const abiCoder = new utils.AbiCoder();
      const constructorData = abiCoder.encode(
        ["address", "address", "string", "string", "address", "bytes", "uint256", "uint256"],
        deployArgs
      );
      const tx = await comptrollerContract._deployMarket(true, constructorData, collateralFactorBN);
      const receipt: TransactionReceipt = await tx.wait();
      console.log(`Ether deployed successfully with tx hash: ${receipt.transactionHash}`);

      const [totalSupply, totalBorrow, underlyingTokens, underlyingSymbols, whitelistedAdmin] =
        await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);

      expect(underlyingTokens[0]).to.eq(ETH_ZERO_ADDRESS);
      expect(underlyingSymbols[0]).to.eq("ETH");

      const fusePoolData = await sdk.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(poolAddress);

      console.log(fusePoolData, "FPD");
    });

    it("should deploy pool from sdk without whitelist", async function () {
      const { bob } = await ethers.getNamedSigners();

      const spoFactory = await ethers.getContractFactory("ChainlinkPriceOracle", bob);
      const spo = await spoFactory.deploy([10]);

      const contractConfig = await getContractsConfig(network.name);
      const sdk = new Fuse(ethers.provider, contractConfig);

      // 50% -> 0.5 * 1e18
      const bigCloseFactor = utils.parseEther((50 / 100).toString());
      // 8% -> 1.08 * 1e8
      const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());

      const [poolAddress, implementationAddress, priceOracleAddress] = await sdk.deployPool(
        "TEST_BOB",
        false,
        bigCloseFactor,
        bigLiquidationIncentive,
        spo.address,
        {},
        { from: bob.address },
        [bob.address]
      );
      console.log(`Pool with address: ${poolAddress}, \noracle address: ${priceOracleAddress} deployed`);
      expect(poolAddress).to.be.ok;
      expect(implementationAddress).to.be.ok;

      const comptrollerAt = await ethers.getContractAt("Comptroller", poolAddress, bob);
      console.log(`ComptrollerAt: ${comptrollerAt.address} has admin: ${await comptrollerAt.admin()}`);

      const { comptroller, name: _unfiliteredName } = await sdk.contracts.FusePoolDirectory.pools(0);
      const comptrollerAt2 = await ethers.getContractAt("Comptroller", comptroller, bob);
      console.log(`Fetched Comptroller: ${comptrollerAt2.address} has admin: ${await comptrollerAt2.admin()}`);

      expect(_unfiliteredName).to.be.equal("TEST_BOB");

      const jrm = await ethers.getContract("JumpRateModel", bob);
      const assets = poolAssets(jrm.address, implementationAddress);

      for (const assetConf of assets.assets) {
        const [assetAddress, cTokenImplementationAddress, irmModel, receipt] = await sdk.deployAsset(
          Fuse.JumpRateModelConf,
          assetConf,
          { from: bob.address }
        );
        console.log("-----------------");
        console.log("deployed asset: ", assetConf.name);
        console.log("Asset Address: ", assetAddress);
        console.log("irmModel: ", irmModel);
        console.log("Implementation Address: ", cTokenImplementationAddress);
        console.log("TX Receipt: ", receipt.transactionHash);
        console.log("-----------------");
      }
      const t = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);
      console.log(t, "pool summary for implementation: ", poolAddress);
      const fusePoolData = await sdk.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(poolAddress);

      console.log(fusePoolData, "FPD");
    });
  });
});
