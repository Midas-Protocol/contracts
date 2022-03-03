import { constants, Contract, providers, utils } from "ethers";
import {deployments, ethers} from "hardhat";
import {createPool, deployAssets, setUpPriceOraclePrices} from "./utils";
import {expect} from "chai";
import {
    KeydonixUniswapTwapPriceOracle,
    CEther,
    Comptroller
} from '../typechain';
import * as OracleSdkAdapter from "@keydonix/uniswap-oracle-sdk-adapter";
import * as OracleSdk from "@keydonix/uniswap-oracle-sdk";
import { DeployedAsset } from "./utils/pool";
import { getAssetsConf } from "./utils/assets";
import { ChainDeployConfig, chainDeployConfig } from "../chainDeploy";

describe.only( "Verify price proof tests",  () => {
    let keydonixOracle: KeydonixUniswapTwapPriceOracle;
    let ethCToken: CEther;
    let eth: DeployedAsset;
    let poolAddress: string;
    let comptroller: Comptroller;

    beforeEach(async () => {
        await deployments.fixture(); // ensure you start from a fresh deployments
        await setUpPriceOraclePrices();
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

        const { chainId } = await ethers.provider.getNetwork();
        const { config: chainDeployParams }: { config: ChainDeployConfig } =
            chainDeployConfig[chainId];

        // let denominationTokenAddress: string = await keydonixOracle.callStatic.denominationToken();
        let denominationTokenAddress: string = chainDeployParams.wBTCToken;
        let tokenAddress = chainDeployParams.wtoken;
        // pancake swap WBNB-BTCB pair
        let uniswapExchangeAddress = BigInt('0x61eb789d75a95caa3ff50ed7e47b96c132fec082');

        const getStorageAt = OracleSdkAdapter.getStorageAtFactory(ethers.provider)
        const getProof = OracleSdkAdapter.getProofFactory(ethers.provider)
        const getBlockByNumber = OracleSdkAdapter.getBlockByNumberFactory(ethers.provider)


        let latestBlockNumber = ethers.provider.blockNumber;

        let latestMinusTen = BigInt(latestBlockNumber - 10);
        const estimatedPrice = await OracleSdk.getPrice(
            getStorageAt,
            getBlockByNumber,
            uniswapExchangeAddress,
            BigInt(denominationTokenAddress),
            latestMinusTen
        );

        console.log(`estimated price ${estimatedPrice}`);

        // const proof = {
        //     block: [1],
        //     accountProofNodesRlp: [1],
        //     reserveAndTimestampProofNodesRlp: [1],
        //     priceAccumulatorProofNodesRlp: [1],
        // };
        const proof = await OracleSdk.getProof(getStorageAt, getProof, getBlockByNumber,
            uniswapExchangeAddress, BigInt(tokenAddress), latestMinusTen);

        console.log(`proof: ${JSON.stringify(proof)}`);

        tx = await keydonixOracle.verifyPrice(tokenAddress, proof);
        rec = await tx.wait();
        expect(rec.status).to.eq(1);
    });
});