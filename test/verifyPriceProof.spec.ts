import { constants, providers } from "ethers";
import {deployments, ethers} from "hardhat";
import {expect} from "chai";
import { KeydonixUniswapTwapPriceOracle } from '../typechain';
import * as OracleSdkAdapter from "@keydonix/uniswap-oracle-sdk-adapter";
import * as OracleSdk from "@keydonix/uniswap-oracle-sdk";
import { ChainDeployConfig, chainDeployConfig } from "../chainDeploy";

describe.only( "Verify price proof tests",  () => {
    let keydonixOracle: KeydonixUniswapTwapPriceOracle;
    let denominationTokenAddress: string;
    let wtoken: string;
    let uniswapExchangeAddress = "0xbB0F21795d19bc297FfA6F771Cca5055D59a35eC";
    // pancake swap WBNB-BTCB pair
    // let uniswapExchangeAddress = BigInt('0x61eb789d75a95caa3ff50ed7e47b96c132fec082');

    // kovan uniswap WETH-TT2 pair
    // let uniswapExchangeAddress = BigInt('0xbB0F21795d19bc297FfA6F771Cca5055D59a35eC');

    beforeEach(async () => {
        const { alice, bob } = await ethers.getNamedSigners();
        console.log(`bobs address ${bob.address}`);
        console.log(`alices address ${alice.address}`);

        // use in case bob has no funds
        // let transactionResponse = await bob.sendTransaction({
        //     to: bob.address,
        //     value: utils.parseEther("1")
        // });
        // console.log(`tx resp ${transactionResponse.value}`);
        let bobsBalance = await bob.getBalance();
        console.log(`bobs balance ${bobsBalance}`);

        const { chainId } = await ethers.provider.getNetwork();
        const { config: chainDeployParams }: { config: ChainDeployConfig } =
            chainDeployConfig[chainId];

        denominationTokenAddress = chainDeployParams.wBTCToken;
        wtoken = chainDeployParams.wtoken;

        let salt = "some_salt";

        // deploy it or find the instance
        let dep = await deployments.deterministic("KeydonixUniswapTwapPriceOracle", {
            from: bob.address,
            salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(salt)),
            args: [],
            log: true,
        });
        const kPO = await dep.deploy();
        console.log("Keydonix Price Oracle: ", kPO.address);

        const keydonixPriceOracle = await ethers.getContract("KeydonixUniswapTwapPriceOracle", bob);
        if ((await keydonixPriceOracle.denominationToken()) == constants.AddressZero) {
            let tx = await keydonixPriceOracle.initialize(
                uniswapExchangeAddress, // uniswapV2Pair,
                denominationTokenAddress,
                wtoken,
                3, // min blocks back
                10 // max blocks back
            );
            await tx.wait();
            console.log("Keydonix Price Oracle initialized", tx.hash);
        } else {
            console.log(`${await keydonixPriceOracle.denominationToken()}`);
            console.log("Keydonix Price Oracle already initialized");
        }

        keydonixOracle = await ethers.getContract("KeydonixUniswapTwapPriceOracle", bob);
    });

    it("should verify an OracleSDK generated proof", async function () {
        let tx: providers.TransactionResponse;
        let rec: providers.TransactionReceipt;

        let dta: string = await keydonixOracle.callStatic.denominationToken();
        console.log(`dta ${dta} wBTCToken ${denominationTokenAddress} wtoken ${wtoken}`);

        let latestBlockNumber = await ethers.provider.getBlockNumber();
        console.log(`latestBlockNumber ${latestBlockNumber}`)

        let latestMinusSome = BigInt(latestBlockNumber - 1);
        console.log(`latest - 10 = ${latestMinusSome}`)

        const getStorageAt = OracleSdkAdapter.getStorageAtFactory(ethers.provider)
        const getProof = OracleSdkAdapter.getProofFactory(ethers.provider)
        const getBlockByNumber = OracleSdkAdapter.getBlockByNumberFactory(ethers.provider)
        // const estimatedPrice = await OracleSdk.getPrice(
        //     getStorageAt,
        //     getBlockByNumber,
        //     BigInt(uniswapExchangeAddress),
        //     BigInt(denominationTokenAddress),
        //     latestMinusSome
        // );
        // console.log(`estimated price ${estimatedPrice}`);
        console.log(`fetching block 0x${latestMinusSome.toString(16)}`)
        const block = await getBlockByNumber(latestMinusSome);
        console.log(`block ${block}`)

        // let exchangeAddress = BigInt(uniswapExchangeAddress);
        // let positions = [BigInt(8), BigInt(9)];
        // const encodedAddress = bigintToHexAddress(exchangeAddress)
        // const encodedPositions = positions.map(bigintToHexQuantity)
        // const encodedBlockTag = bigintToHex(latestMinusSome)
        //
        // console.log(`get proof params encodedAddress ${encodedAddress} encodedPositions ${encodedPositions} encodedBlockTag ${encodedBlockTag}`)
        // const result = await ethers.provider.send('eth_getProof', [
        //     encodedAddress, encodedPositions, encodedBlockTag
        // ]);
        // console.log(`result ${result}`)
        //
        // const proof1 = await getProof(exchangeAddress, positions, latestMinusSome)
        // console.log(`proof1 ${proof1}`)
        // const proof = await OracleSdk.getProof(
        //     getStorageAt,
        //     getProof,
        //     getBlockByNumber,
        //     BigInt(uniswapExchangeAddress),
        //     BigInt(wtoken),
        //     latestMinusSome
        // );
        // console.log(`proof: ${JSON.stringify(proof)}`);

        const proof = {
            block: [1],
            accountProofNodesRlp: [1],
            reserveAndTimestampProofNodesRlp: [1],
            priceAccumulatorProofNodesRlp: [1],
        };

        tx = await keydonixOracle.verifyPrice(denominationTokenAddress, proof);
        rec = await tx.wait();
        expect(rec.status).to.eq(1);

        console.log(`asking for the price`);
        let price = await keydonixOracle.price(wtoken);
        console.log(`got price ${price}`);
    });

    function bigintToHexAddress(value: bigint): string {
        return `0x${value.toString(16).padStart(40, '0')}`
    }

    function bigintToHexQuantity(value: bigint): string {
        return `0x${value.toString(16).padStart(64, '0')}`
    }

    function bigintToHex(value: bigint): string {
        return `0x${value.toString(16)}`
    }

});