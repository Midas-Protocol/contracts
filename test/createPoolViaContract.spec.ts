import { deployments, ethers } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
import { Fuse } from "../dist/esm/src";
import { constants, utils } from "ethers";
import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { Comptroller, FusePoolDirectory, SimplePriceOracle, Unitroller } from "../typechain";
import { getAssetsConf } from "./utils/assets";
import { chainDeployConfig } from "../chainDeploy";
import { setUpPriceOraclePrices } from "./utils";

use(solidity);

describe("FusePoolDirectory", function () {
  let spo: SimplePriceOracle;
  let fpdWithSigner: FusePoolDirectory;
  let implementationComptroller: Comptroller;

  this.beforeEach(async () => {
    const { chainId } = await ethers.provider.getNetwork();
    if (chainId === 1337) {
      await deployments.fixture();
    }
    await setUpPriceOraclePrices();
  });

  describe("Deploy pool", async function () {
    it("should deploy the pool via contract", async function () {
      this.timeout(120_000);
      const { alice } = await ethers.getNamedSigners();
      console.log("alice: ", alice.address);
      const { chainId } = await ethers.provider.getNetwork();

      const sdk = new Fuse(ethers.provider, chainId);
      spo = await ethers.getContractAt("MasterPriceOracle", sdk.oracles.MasterPriceOracle.address, alice);

      fpdWithSigner = await ethers.getContractAt("FusePoolDirectory", sdk.contracts.FusePoolDirectory.address, alice);
      implementationComptroller = await ethers.getContractAt("Comptroller", sdk.chainDeployment.Comptroller.address);

      //// DEPLOY POOL
      const POOL_NAME = "TEST";
      const FUSE_ADMIN_ADDRESS = sdk.contracts.FuseFeeDistributor.address;
      const bigCloseFactor = utils.parseEther((50 / 100).toString());
      const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());
      let abiCoder = new utils.AbiCoder();
      const deployedPool = await fpdWithSigner.deployPool(
        POOL_NAME,
        implementationComptroller.address,
        abiCoder.encode(["address"], [FUSE_ADMIN_ADDRESS]),
        true,
        bigCloseFactor,
        bigLiquidationIncentive,
        spo.address
      );
      expect(deployedPool).to.be.ok;
      const depReceipt = await deployedPool.wait();
      console.log("Deployed pool");

      // Confirm Unitroller address
      const saltsHash = utils.solidityKeccak256(
        ["address", "string", "uint"],
        [alice.address, POOL_NAME, depReceipt.blockNumber]
      );
      const deployCode = utils.keccak256(
        (await deployments.getArtifact("Unitroller")).bytecode +
          abiCoder.encode(["address"], [FUSE_ADMIN_ADDRESS]).slice(2)
      );
      let poolAddress = utils.getCreate2Address(fpdWithSigner.address, saltsHash, deployCode);
      console.log("poolAddress: ", poolAddress);

      const pools = await fpdWithSigner.getPoolsByAccount(alice.address);
      const pool = pools[1].at(-1);
      expect(pool.comptroller).to.eq(poolAddress);

      const allPools = await sdk.contracts.FusePoolDirectory.callStatic.getAllPools();
      const { comptroller, name: _unfilteredName } = await allPools.filter((p) => p.creator === alice.address).at(-1);

      expect(comptroller).to.eq(poolAddress);
      expect(_unfilteredName).to.eq(POOL_NAME);

      const unitroller = (await ethers.getContractAt("Unitroller", poolAddress, alice)) as Unitroller;
      const adminTx = await unitroller._acceptAdmin();
      await adminTx.wait();

      const comptrollerContract = await ethers.getContractAt("Comptroller", comptroller, alice);
      const admin = await comptrollerContract.admin();
      expect(admin).to.eq(alice.address);

      //// DEPLOY ASSETS
      const jrm = await ethers.getContractAt("JumpRateModel", sdk.irms.JumpRateModel.address, alice);

      const assets = await getAssetsConf(comptroller, FUSE_ADMIN_ADDRESS, jrm.address, ethers);
      const nativeAsset = assets.find((a) => a.underlying === constants.AddressZero);
      const erc20Asset = assets.find((a) => a.underlying != constants.AddressZero);

      const reserveFactorBN = utils.parseUnits((nativeAsset.reserveFactor / 100).toString());
      const adminFeeBN = utils.parseUnits((nativeAsset.adminFee / 100).toString());
      const collateralFactorBN = utils.parseUnits((nativeAsset.collateralFactor / 100).toString());

      let deployArgs = [
        nativeAsset.comptroller,
        FUSE_ADMIN_ADDRESS,
        nativeAsset.interestRateModel,
        nativeAsset.name,
        nativeAsset.symbol,
        sdk.chainDeployment.CEtherDelegate.address,
        "0x00",
        reserveFactorBN,
        adminFeeBN,
      ];
      let constructorData = abiCoder.encode(
        ["address", "address", "address", "string", "string", "address", "bytes", "uint256", "uint256"],
        deployArgs
      );
      let errorCode;
      errorCode = await comptrollerContract.callStatic._deployMarket(
        constants.AddressZero,
        constructorData,
        collateralFactorBN
      );
      expect(errorCode.toNumber()).to.eq(0);

      let tx = await comptrollerContract._deployMarket(true, constructorData, collateralFactorBN);
      let receipt: TransactionReceipt = await tx.wait();
      console.log(`Ether deployed successfully with tx hash: ${receipt.transactionHash}`);

      const [, , underlyingTokens, underlyingSymbols] = await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(
        poolAddress
      );

      expect(underlyingTokens[0]).to.eq(constants.AddressZero);

      expect(underlyingSymbols[0]).to.eq(chainDeployConfig[chainId].config.nativeTokenSymbol);

      let fusePoolData = await sdk.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(poolAddress);
      expect(fusePoolData[0][1]).to.eq(constants.AddressZero);

      deployArgs = [
        erc20Asset.underlying,
        erc20Asset.comptroller,
        FUSE_ADMIN_ADDRESS,
        erc20Asset.interestRateModel,
        erc20Asset.name,
        erc20Asset.symbol,
        sdk.chainDeployment.CErc20Delegate.address,
        "0x00",
        reserveFactorBN,
        adminFeeBN,
      ];

      abiCoder = new utils.AbiCoder();
      constructorData = abiCoder.encode(
        ["address", "address", "address", "address", "string", "string", "address", "bytes", "uint256", "uint256"],
        deployArgs
      );

      errorCode = await comptrollerContract.callStatic._deployMarket(false, constructorData, collateralFactorBN);
      expect(errorCode.toNumber()).to.eq(0);

      tx = await comptrollerContract._deployMarket(false, constructorData, collateralFactorBN);
      receipt = await tx.wait();
      console.log(`${erc20Asset.name} deployed successfully with tx hash: ${receipt.transactionHash}`);

      fusePoolData = await sdk.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(poolAddress);
      expect(fusePoolData.length).to.eq(2);
    });
  });
});
