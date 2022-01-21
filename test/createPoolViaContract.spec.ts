import { deployments, ethers } from "hardhat";
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";
import { cERC20Conf, Fuse } from "../lib/esm/src";
import { constants, utils } from "ethers";
import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { ETH_ZERO_ADDRESS } from "./utils";

use(solidity);

describe("FusePoolDirectory", function () {
  describe("Deploy pool", async function () {
    it("should deploy the pool via contract", async function () {
      this.timeout(120_000);
      const { alice } = await ethers.getNamedSigners();
      console.log("alice: ", alice.address);

      const cpoFactory = await ethers.getContractFactory("MockPriceOracle", alice);
      const cpo = await cpoFactory.deploy([10]);

      const fpdWithSigner = await ethers.getContract("FusePoolDirectory", alice);
      const implementationComptroller = await ethers.getContract("Comptroller");

      //// DEPLOY POOL
      const POOL_NAME = "TEST";
      const bigCloseFactor = utils.parseEther((50 / 100).toString());
      const bigLiquidationIncentive = utils.parseEther((8 / 100 + 1).toString());
      const deployedPool = await fpdWithSigner.deployPool(
        POOL_NAME,
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
        [alice.address, POOL_NAME, depReceipt.blockNumber]
      );
      const byteCodeHash = utils.keccak256((await deployments.getArtifact("Unitroller")).bytecode);
      let poolAddress = utils.getCreate2Address(fpdWithSigner.address, saltsHash, byteCodeHash);
      console.log("poolAddress: ", poolAddress);

      const pools = await fpdWithSigner.getPoolsByAccount(alice.address);
      const pool = pools[1].at(-1);
      expect(pool.comptroller).to.eq(poolAddress);

      const sdk = new Fuse(ethers.provider, "1337");
      const allPools = await sdk.contracts.FusePoolDirectory.callStatic.getAllPools();
      const { comptroller, name: _unfiliteredName } = await allPools.filter((p) => p.creator === alice.address).at(-1);

      expect(comptroller).to.eq(pool.comptroller);
      expect(_unfiliteredName).to.eq(POOL_NAME);

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
        collateralFactor: 75,
        reserveFactor: 20,
        adminFee: 0,
        bypassPriceFeedCheck: true,
        initialExchangeRateMantissa: constants.One,
      };
      const reserveFactorBN = utils.parseUnits((ethConf.reserveFactor / 100).toString());
      const adminFeeBN = utils.parseUnits((ethConf.adminFee / 100).toString());
      const collateralFactorBN = utils.parseUnits((ethConf.collateralFactor / 100).toString());

      let deployArgs = [
        ethConf.comptroller,
        ethConf.interestRateModel,
        ethConf.name,
        ethConf.symbol,
        sdk.chainDeployment.CEtherDelegate.address,
        "0x00",
        reserveFactorBN,
        adminFeeBN,
      ];
      let abiCoder = new utils.AbiCoder();
      let constructorData = abiCoder.encode(
        ["address", "address", "string", "string", "address", "bytes", "uint256", "uint256"],
        deployArgs
      );
      let tx = await comptrollerContract._deployMarket(true, constructorData, collateralFactorBN);
      let receipt: TransactionReceipt = await tx.wait();
      console.log(`Ether deployed successfully with tx hash: ${receipt.transactionHash}`);

      const [totalSupply, totalBorrow, underlyingTokens, underlyingSymbols, whitelistedAdmin] =
        await sdk.contracts.FusePoolLens.callStatic.getPoolSummary(poolAddress);

      expect(underlyingTokens[0]).to.eq(ETH_ZERO_ADDRESS);
      expect(underlyingSymbols[0]).to.eq("ETH");

      let fusePoolData = await sdk.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(poolAddress);
      expect(fusePoolData[0][1]).to.eq(ETH_ZERO_ADDRESS);

      const touchConf: cERC20Conf = {
        underlying: await ethers.getContract("TOUCHToken", alice).then((c) => c.address),
        comptroller: comptroller,
        interestRateModel: jrm.address,
        name: "Midas TOUCH Token",
        symbol: "TOUCH",
        decimals: 18,
        admin: "true",
        collateralFactor: 65,
        reserveFactor: 20,
        adminFee: 0,
        bypassPriceFeedCheck: true,
      };
      deployArgs = [
        touchConf.underlying,
        touchConf.comptroller,
        touchConf.interestRateModel,
        touchConf.name,
        touchConf.symbol,
        sdk.chainDeployment.CErc20Delegate.address,
        "0x00",
        reserveFactorBN,
        adminFeeBN,
      ];

      abiCoder = new utils.AbiCoder();
      constructorData = abiCoder.encode(
        ["address", "address", "address", "string", "string", "address", "bytes", "uint256", "uint256"],
        deployArgs
      );
      tx = await comptrollerContract._deployMarket(false, constructorData, collateralFactorBN);
      receipt = await tx.wait();
      console.log(`${touchConf.name} deployed successfully with tx hash: ${receipt.transactionHash}`);

      fusePoolData = await sdk.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(poolAddress);
      expect(fusePoolData.length).to.eq(2);
    });
  });
});
