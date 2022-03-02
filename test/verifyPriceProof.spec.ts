import { constants, Contract, providers, utils } from "ethers";
import {ethers} from "hardhat";
import {createPool, deployAssets, setupTest} from "./utils";
import {expect} from "chai";
import {
    KeydonixUniswapTwapPriceOracle,
    CEther,
    Comptroller
} from '../typechain';
import * as OracleSdkAdapter from "@keydonix/uniswap-oracle-sdk-adapter";
import * as OracleSdk from "@keydonix/uniswap-oracle-sdk";
import {DeployedAsset, getAssetsConf} from "./utils/pool";

describe.only( "Verify price proof tests",  () => {
    let keydonixOracle: KeydonixUniswapTwapPriceOracle;
    let ethCToken: CEther;
    let eth: DeployedAsset;
    let poolAddress: string;
    let comptroller: Comptroller;

    beforeEach(async () => {
        await setupTest();
        const { bob } = await ethers.getNamedSigners();
        // [poolAddress] = await createPool({});
        // const assets = await getAssetsConf(poolAddress);
        // const deployedAssets = await deployAssets(assets.assets, bob);
        //
        // eth = deployedAssets.find((a) => a.underlying === constants.AddressZero);

        keydonixOracle = await ethers.getContract("KeydonixUniswapTwapPriceOracle", bob);
        // ethCToken = (await ethers.getContractAt("CEther", eth.assetAddress)) as CEther;
        ethCToken = (await ethers.getContract("CEtherDelegate")) as CEther;
        comptroller = await ethers.getContract("Comptroller");
    });

    it("should verify an OracleSDK generated proof", async function () {
        let tx: providers.TransactionResponse;
        let rec: providers.TransactionReceipt;
        const { bob } = await ethers.getNamedSigners();

        const proof = {
            block: [1],
            accountProofNodesRlp: [1],
            reserveAndTimestampProofNodesRlp: [1],
            priceAccumulatorProofNodesRlp: [1],
        };

        tx = await keydonixOracle.verifyPrice(ethCToken.address, proof);
        rec = await tx.wait();
        expect(rec.status).to.eq(1);

        let borrowTx = await comptroller.borrowAllowedWithPriceProof(ethCToken.address, bob.address, 1, proof, keydonixOracle.address);
        let borrowRec = await borrowTx.wait();

        // let denominationTokenAddress: string = await keydonixOracle.callStatic.denominationToken();
        // let uniswapExchangeAddress = BigInt(1);
        // const latestBlockNumber = BigInt(1);
        //
        // const getStorageAt = OracleSdkAdapter.getStorageAtFactory(ethers.provider)
        // const getProof = OracleSdkAdapter.getProofFactory(ethers.provider)
        // const getBlockByNumber = OracleSdkAdapter.getBlockByNumberFactory(ethers.provider)
        // const estimatedPrice = await OracleSdk.getPrice(
        //     getStorageAt,
        //     getBlockByNumber,
        //     uniswapExchangeAddress,
        //     BigInt(denominationTokenAddress),
        //     latestBlockNumber
        // );
        //
        // console.log(`estimated price ${estimatedPrice}`);

        // const proof = await OracleSdk.getProof(getStorageAt, getProof, getBlockByNumber,
        //     uniswapExchangeAddress, tokenAddress, latestBlockNumber);
        // console.log(`proof: ${JSON.stringify(proof)}`);

    });
});