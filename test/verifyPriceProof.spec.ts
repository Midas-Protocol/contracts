import { constants, providers, utils } from "ethers";
import { deployments, ethers } from "hardhat";
import { expect } from "chai";
import { KeydonixUniswapTwapPriceOracle, Comptroller } from "../typechain";
import * as OracleSdkAdapter from "@keydonix/uniswap-oracle-sdk-adapter";
import * as OracleSdk from "@keydonix/uniswap-oracle-sdk";
import { ChainDeployConfig, chainDeployConfig } from "../chainDeploy";

describe("Verify price proof tests", () => {
  let keydonixOracle: KeydonixUniswapTwapPriceOracle;
  let uniswapFactory;
  let denominationTokenAddress: string;
  let wtoken: string;
  let uniswapExchangeAddress: string;
  let token0;
  let token1;

  // pancake swap WBNB-BTCB pair
  // uniswapExchangeAddress = "0x61eb789d75a95caa3ff50ed7e47b96c132fec082";
  // kovan uniswap WETH-TT2 pair
  // uniswapExchangeAddress = "0xbB0F21795d19bc297FfA6F771Cca5055D59a35eC";
  // some random evmos uniswap pair
  // uniswapExchangeAddress = "0x11024B5ebF766F889E952874cE1EAA34e1F7dA90";

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
    const { config: chainDeployParams }: { config: ChainDeployConfig } = chainDeployConfig[chainId];
    console.log(`chainDeployParams ${chainDeployParams}`);

    // console.log(`chainDeployParams.wBTCToken, chainDeployParams.wtoken ${chainDeployParams.wBTCToken} ${chainDeployParams.wtoken}`)
    denominationTokenAddress = chainDeployParams.wBTCToken;
    wtoken = chainDeployParams.wtoken;

    uniswapFactory = await ethers.getContractAt(
      "IUniswapV2Factory",
      chainDeployParams.uniswap.uniswapV2FactoryAddress
    );
    console.log(`uniswap factory ${uniswapFactory.address}`);

    let pair0Address = await uniswapFactory.callStatic.allPairs(1);
    // let pair0Address = "0xaaeF854894Ae5b79cB396b938b0eB9a13f5510Fc";
    uniswapExchangeAddress = pair0Address;
    console.log(`pair0 ${pair0Address}`);

    const pair0 = await ethers.getContractAt("IUniswapV2Pair", pair0Address);

    token0 = await pair0.token0();
    token1 = await pair0.token1();

    console.log(`token0 ${token0} token1 ${token1} at exchange ${pair0Address}`);

    // deploy it or find the instance
    let dep = await deployments.deterministic("KeydonixUniswapTwapPriceOracle", {
      from: bob.address,
      salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SALT")),
      args: [],
      log: true,
    });
    const kPO = await dep.deploy();
    console.log("Keydonix Price Oracle: ", kPO.address);
    console.log(`kPO ${kPO}`);

    const keydonixPriceOracle = await ethers.getContract("KeydonixUniswapTwapPriceOracle", bob);
    if ((await keydonixPriceOracle.denominationToken()) == constants.AddressZero) {
      let tx = await keydonixPriceOracle.initialize(
        chainDeployParams.uniswap.uniswapV2FactoryAddress, // factory,
        denominationTokenAddress,
        wtoken,
        3, // min blocks back
        Math.max(chainDeployParams.blocksPerYear / (365 * 24 * 3), 255) // max blocks back = 20 mins back
      );
      await tx.wait();
      console.log("Keydonix Price Oracle initialized", tx.hash);
    } else {
      console.log(`${await keydonixPriceOracle.denominationToken()}`);
      console.log("Keydonix Price Oracle already initialized");
    }

    keydonixOracle = await ethers.getContract("KeydonixUniswapTwapPriceOracle", bob);
    console.log(`keydonixOracle ${keydonixOracle}`);
    // comptroller = await ethers.getContract("Comptroller", bob);
  });

  it("should be able to verify the price with proof and make another action in a single tx", async function () {
    let verifyPriceMethodId = ethers.utils.id("verifyPrice(address,(bytes,bytes,bytes,bytes))");

    console.log(`method id ${verifyPriceMethodId}`);

    const proof = {
      block: [1],
      accountProofNodesRlp: [1],
      reserveAndTimestampProofNodesRlp: [1],
      priceAccumulatorProofNodesRlp: [1],
    };

    let args = [denominationTokenAddress, proof];
    const abiCoder = new utils.AbiCoder();
    let encodedParams = abiCoder.encode(
      [
        "address",
        "(bytes block,bytes accountProofNodesRlp,bytes reserveAndTimestampProofNodesRlp,bytes priceAccumulatorProofNodesRlp)",
      ],
      args
    );
    let data = ethers.utils.hexConcat([verifyPriceMethodId, encodedParams]);

    console.log(` data is ${data}`);

    let tx: providers.TransactionResponse;
    let rec: providers.TransactionReceipt;

    // tx = keydonixOracle.multicall(data);
    // rec = await tx.wait();
    // expect(rec.status).to.eq(1);
  });

  it.only("should verify an OracleSDK generated proof", async function () {
    let tx: providers.TransactionResponse;
    let rec: providers.TransactionReceipt;

    // let dta: string = await keydonixOracle.callStatic.denominationToken();
    // console.log(`dta ${dta} wBTCToken ${denominationTokenAddress} wtoken ${wtoken}`);

    let latestBlockNumber = await ethers.provider.getBlockNumber();
    console.log(`latestBlockNumber ${latestBlockNumber}`);

    let latestMinusSome = BigInt(latestBlockNumber - 10);
    console.log(`latest - 10 = ${latestMinusSome}`);

    let exchangeAddress = BigInt(uniswapExchangeAddress);

    const getStorageAt = OracleSdkAdapter.getStorageAtFactory(ethers.provider);
    const getProof = OracleSdkAdapter.getProofFactory(ethers.provider);
    const getBlockByNumber = OracleSdkAdapter.getBlockByNumberFactory(ethers.provider);
    const estimatedPrice = await OracleSdk.getPrice(
      getStorageAt,
      getBlockByNumber,
      exchangeAddress,
      BigInt(token1),
      latestMinusSome
    );
    console.log(`estimated price ${estimatedPrice}`);

    let positions = [BigInt(8), BigInt(9)];
    // const encodedAddress = bigintToHexAddress(exchangeAddress);
    // const encodedPositions = positions.map(bigintToHexQuantity);
    // const encodedBlockTag = bigintToHex(latestMinusSome);
    //
    // console.log(
    //   `get proof params encodedAddress ${encodedAddress} encodedPositions ${encodedPositions} encodedBlockTag ${encodedBlockTag}`
    // );
    // const result = await ethers.provider.send("eth_getProof", [encodedAddress, encodedPositions, encodedBlockTag]);
    // console.log(`result ${JSON.stringify(result)}`)

    // const proof1 = await getProof(exchangeAddress, positions, latestMinusSome);
    // console.log(`proof1 ${proof1}`);

    const proof = await OracleSdk.getProof(
        getStorageAt,
        getProof,
        getBlockByNumber,
        exchangeAddress,
        BigInt(token1),
        latestMinusSome
    );
    console.log(`proof: ${Object.keys(proof)}`);

    // const proof = {
    //   block: [1],
    //   accountProofNodesRlp: [1],
    //   reserveAndTimestampProofNodesRlp: [1],
    //   priceAccumulatorProofNodesRlp: [1],
    // };

    let maxBB = await keydonixOracle.callStatic.maxBlocksBack();
    let minBB = await keydonixOracle.callStatic.minBlocksBack();

    console.log(`max ${maxBB} min ${minBB}`);

    let pvBefore = await keydonixOracle.callStatic.priceVerifications(token1);
    console.log(`pvBefore ${pvBefore}`);

    console.log(`needs pair ${token1} / ${denominationTokenAddress}`);
    let pricePair = await uniswapFactory.callStatic.getPair(token1, denominationTokenAddress);
    console.log(`pp ${pricePair}`);


    let factory = await keydonixOracle.callStatic.uniswapV2Factory();
    console.log(`factory ${factory}`);

    console.log(`verifying the price`)
    await keydonixOracle.callStatic.verifyPriceUnderlying(token1, proof, {gasLimit: 3e7});
    // tx = await keydonixOracle.callStatic.verifyPriceUnderlying(token1, proof, {gasLimit: 1e7});
    // rec = await tx.wait();
    // expect(rec.status).to.eq(1);

    // let price = await keydonixOracle.callStatic.getPrice(pricePair, denominationTokenAddress, minBB, maxBB, proof);
    // let result = await keydonixOracle.callStatic.getAccountStorageRoot(pricePair, proof);
    // console.log(`getAccountStorageRoot ${result}`);

    let pv = await keydonixOracle.callStatic.priceVerifications(token1);
    console.log(`pv ${pv}`);

    console.log(`asking for the price`);
    let priceDta = await keydonixOracle.callStatic.price(token1);
    console.log(`got price ${priceDta} for ${token1}`);
    // let pricewtoken = await keydonixOracle.callStatic.price(wtoken);
    // console.log(`got price ${pricewtoken} for ${wtoken}`);
  });

  // package.json : "file:../../uniswap-oracle/sdk-adapter",
  function bigintToHexAddress(value: bigint): string {
    return `0x${value.toString(16).padStart(40, "0")}`;
  }

  function bigintToHexQuantity(value: bigint): string {
    return `0x${value.toString(16).padStart(64, "0")}`;
  }

  function bigintToHex(value: bigint): string {
    return `0x${value.toString(16)}`;
  }
});
