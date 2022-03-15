import { constants, providers, utils } from "ethers";
import { deployments, ethers } from "hardhat";
import { expect } from "chai";
import { KeydonixUniswapTwapPriceOracle, Comptroller } from "../typechain";
import * as OracleSdkAdapter from "@keydonix/uniswap-oracle-sdk-adapter";
import * as OracleSdk from "@keydonix/uniswap-oracle-sdk";
import { ChainDeployConfig, chainDeployConfig } from "../chainDeploy";
import {Proof} from "@keydonix/uniswap-oracle-sdk";
import { BaseTrie as Trie } from 'merkle-patricia-tree'
import exp from "constants";

describe.only("Verify price proof tests", () => {
  let keydonixOracle: KeydonixUniswapTwapPriceOracle;
  let uniswapFactory;
  let denominationTokenAddress: string;
  let wtoken: string;
  let uniswapExchangeAddress: string;
  let token0;
  let token1;

  beforeEach(async () => {
    const { alice, bob } = await ethers.getNamedSigners();
    console.log(`bobs address ${bob.address}`);
    console.log(`alices address ${alice.address}`);
    let alicesBalance = await alice.getBalance();
    console.log(`alices balance ${alicesBalance}`);
    let bobsBalance = await bob.getBalance();
    console.log(`bobs balance ${bobsBalance}`);

    if (alicesBalance.isZero()) {
      // use in case bob has no funds
      let transactionResponse = await bob.sendTransaction({
          to: alice.address,
          value: bobsBalance.div(2)
      });
      console.log(`tx resp ${transactionResponse.value}`);
    }

    const { chainId } = await ethers.provider.getNetwork();

    let chainDeployParams: ChainDeployConfig;
    if (chainId == 97) {
      chainDeployParams = {
        wtoken: "0x8a9424745056Eb399FD19a0EC26A14316684e274", // DAI
        //"0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", // WBNB
        nativeTokenUsdChainlinkFeed: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
        nativeTokenName: "Binance Network Token (Testnet)",
        nativeTokenSymbol: "TBNB",
        stableToken: "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee",
        wBTCToken: "0x6ce8dA28E2f864420840cF74474eFf5fD80E65B8",
        blocksPerYear: 20 * 24 * 365 * 60,
        uniswap: {
          hardcoded: [],
          uniswapData: [],
          pairInitHashCode: "0x",
          uniswapV2RouterAddress: "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3",
          uniswapV2FactoryAddress: "0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc",
          uniswapOracleInitialDeployTokens: [
            "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7", // BUSD
            "0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684", // USDT
            "0x8babbb98678facc7342735486c851abd7a0d17ca", // ETH
            "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", // WBNB
            // "0x6ce8da28e2f864420840cf74474eff5fd80e65b8", // (BTCB)
            "0x8a9424745056Eb399FD19a0EC26A14316684e274", // DAI
            "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee", // (BUSD)

            // pool (BTCB)/WBNB/BUSD 0x8871D160E38F083c532f6CC831681C34d8686F20
            // pair BUSD/ETH 0x6a9D99Db0bD537f3aC57cBC316A9DD8b11A703aC
            // pair BUSD/USDT 0x5126C1B8b4368c6F07292932451230Ba53a6eB7A
            // pair ETH/USDT 0x8b4C4cc21865A792eb248AC0dB88859E17697eCe
          ],
        },
      };
    } else {
      chainDeployParams = chainDeployConfig[chainId].config;
    }

    console.log(`chainDeployParams ${chainDeployParams}`);

    denominationTokenAddress = chainDeployParams.wtoken;
    wtoken = chainDeployParams.wtoken;

    uniswapFactory = await ethers.getContractAt(
      "IUniswapV2Factory",
      chainDeployParams.uniswap.uniswapV2FactoryAddress
    );
    // let tokens = chainDeployParams.uniswap.uniswapOracleInitialDeployTokens;
    // await searchPairs(uniswapFactory, tokens);
    // uniswapFactory = await ethers.getContractAt(
    //   "IUniswapV2Factory",
    //   chainDeployConfig[chainId].config.uniswap.uniswapV2FactoryAddress
    // );
    // await searchPairs(uniswapFactory, tokens);


    token0 = chainDeployParams.uniswap.uniswapOracleInitialDeployTokens[0];
    token1 = chainDeployParams.uniswap.uniswapOracleInitialDeployTokens[1];

    uniswapExchangeAddress = await uniswapFactory.callStatic.getPair(token0, token1);
    // uniswapExchangeAddress = "0xaaeF854894Ae5b79cB396b938b0eB9a13f5510Fc";
    console.log(`token0 ${token0} token1 ${token1} at exchange ${uniswapExchangeAddress}`);

    // deploy it or find the instance
    let dep = await deployments.deterministic("KeydonixUniswapTwapPriceOracle", {
      from: bob.address,
      salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SALT")),
      args: [],
      log: true,
    });
    const kPO = await dep.deploy();
    console.log("Keydonix Price Oracle: ", kPO.address);

    const keydonixPriceOracle = await ethers.getContract("KeydonixUniswapTwapPriceOracle", bob);
    if ((await keydonixPriceOracle.denominationToken()) == constants.AddressZero) {
      let tx = await keydonixPriceOracle.initialize(
        chainDeployParams.uniswap.uniswapV2FactoryAddress, // factory,
        denominationTokenAddress,
        wtoken,
        3, // min blocks back
        Math.min(chainDeployParams.blocksPerYear / (365 * 24 * 3), 255) // max blocks back = 20 mins back
      );
      await tx.wait();
      console.log("Keydonix Price Oracle initialized", tx.hash);
    } else {
      console.log(`denomination token ${await keydonixPriceOracle.denominationToken()}`);
      console.log("Keydonix Price Oracle already initialized");
    }

    keydonixOracle = await ethers.getContract("KeydonixUniswapTwapPriceOracle", bob);
    console.log(`keydonixOracle ${keydonixOracle.address}`);
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

  it("should verify an OracleSDK generated proof", async function () {
    this.timeout(220000);

    let tx: providers.TransactionResponse;
    let rec: providers.TransactionReceipt;

    let maxBB = await keydonixOracle.callStatic.maxBlocksBack();
    let minBB = await keydonixOracle.callStatic.minBlocksBack();
    console.log(`max ${maxBB} min ${minBB}`);

    let latestBlockNumber = await ethers.provider.getBlockNumber();
    console.log(`latestBlockNumber ${latestBlockNumber}`);

    let latestMinusSome = BigInt(latestBlockNumber - 10);
    console.log(`latest - 10 = ${latestMinusSome}`);

    console.log(`estimating the price for ${token1} at exchange ${uniswapExchangeAddress}`)
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

    let proof = await OracleSdk.getProof(
        getStorageAt,
        getProof,
        getBlockByNumber,
        exchangeAddress,
        BigInt(token1),
        latestMinusSome
    );

    console.log(`proof: 
      ${ethers.utils.hexlify(proof.block)}
      ${ethers.utils.hexlify(proof.accountProofNodesRlp)}
      ${ethers.utils.hexlify(proof.priceAccumulatorProofNodesRlp)}
      ${ethers.utils.hexlify(proof.reserveAndTimestampProofNodesRlp)}
    `);

    let rlpDecoded = ethers.utils.RLP.decode(proof.block);
    if (rlpDecoded.length == 13) {
      // proof is missing empty fields for mixHash and nonce
      // add empty mixHash
      rlpDecoded[rlpDecoded.length] = "0x0000000000000000000000000000000000000000000000000000000000000000";
      // add empty nonce
      rlpDecoded[rlpDecoded.length] = "0x0000000000000000";
      let rlpEncoded = ethers.utils.RLP.encode(rlpDecoded);
      let derivedBlockHash = ethers.utils.keccak256(rlpEncoded);
      console.log(`derived block hash ${derivedBlockHash}`);
      proof = {
        block: ethers.utils.arrayify(rlpEncoded),
        accountProofNodesRlp: proof.accountProofNodesRlp,
        priceAccumulatorProofNodesRlp: proof.priceAccumulatorProofNodesRlp,
        reserveAndTimestampProofNodesRlp: proof.reserveAndTimestampProofNodesRlp
      }
    }
    console.log(`proof account nodes:
      ${ethers.utils.hexlify(proof.accountProofNodesRlp)}
    `);

    // path = "0xa04c5251912737031e360e1e2a529ce6e3a350c7d5778bf876fda2db303aa3ff"
    let encodedPath = ethers.utils.solidityKeccak256(["address"], ["0xaF9399F70d896dA0D56A4B2CbF95F4E90a6B99e8"]);
    let encodedPath1 = ethers.utils.solidityPack(["address"], ["0xaF9399F70d896dA0D56A4B2CbF95F4E90a6B99e8"]);
    let encodedPath2 = ethers.utils.soliditySha256(["address"], ["0xaF9399F70d896dA0D56A4B2CbF95F4E90a6B99e8"]);

    let accountProofNodes: any[] = ethers.utils.RLP.decode(proof.accountProofNodesRlp);
    console.log(`
    accountProofNodes ${accountProofNodes}
    `);
    let firstNode = ethers.utils.RLP.encode(accountProofNodes[0]);
    console.log(`
    firstNode ${firstNode}
    `);

    let shouldBeStateRoot = ethers.utils.keccak256(firstNode);
    console.log(`
    shouldBeStateRoot ${shouldBeStateRoot}
    `);

    let block: OracleSdk.Block = await getBlockByNumber(latestMinusSome);
    // let hex = `0x${block.stateRoot.toString(16)}`;
    let stateRootHex = ethers.utils.hexlify(block.stateRoot);
    console.log(`
    encodedPath ${encodedPath}
    encodedPath1 ${encodedPath1}
    encodedPath2 ${encodedPath2}
    `);


    // TODO figure out why the BSC API returns proof/state root in a wrong order (not adhering to the path)
    walkTrie(stateRootHex, encodedPath, ethers.utils.hexlify(proof.accountProofNodesRlp));

    // let proof1 = accountProofNodes.map(node => Buffer.from(node));
    // let trie = await Trie.fromProof(proof1);
    // await trie
    //   .walkTrie(Buffer.from(ethers.utils.arrayify(hex)),
    //     async (nodeRef, node, key, walkController) => {
    //       let path = await trie.findPath(nodeRef);
    //       console.log(path.stack.map(tn => tn.hash).join(" => "));
    //     }
    //   );

    let value = await Trie.verifyProof(
      Buffer.from(ethers.utils.arrayify(stateRootHex)),
      Buffer.from(ethers.utils.arrayify(encodedPath)),
      accountProofNodes
    );
    console.log(`verified value ${value}`);

    let pvBefore = await keydonixOracle.callStatic.priceVerifications(token1);
    console.log(`price verification before ${pvBefore}`);

    console.log(`needs pair ${token1} / ${denominationTokenAddress}`);
    let pricePair = await uniswapFactory.callStatic.getPair(token1, denominationTokenAddress);
    console.log(`found pair ${pricePair}`);


    console.log(`full proof`)
    // let estimatedGas = await keydonixOracle.estimateGas.verifyPriceUnderlying(token1, proof);
    // console.log(`estimated gas ${estimatedGas}`);
    tx = await keydonixOracle.verifyPriceUnderlying(token1, proof, {gasLimit: 2e7, gasPrice: ethers.utils.parseEther("0.00000001")});
    rec = await tx.wait();
    expect(rec.status).to.eq(1);


    // let result = await keydonixOracle.callStatic.getAccountStorageRoot(pricePair, proof);
    // console.log(`getAccountStorageRoot ${result}`);

    let pv = await keydonixOracle.callStatic.priceVerifications(token1);
    console.log(`price verification after ${pv}`);

    console.log(`asking for the price`);
    let priceDta = await keydonixOracle.callStatic.price(token1, {gasLimit: 2e7, gasPrice: ethers.utils.parseEther("0.00000001")});
    console.log(`got price ${priceDta} for ${token1}`);
    let pricewtoken = await keydonixOracle.callStatic.price(wtoken);
    console.log(`got price ${pricewtoken} for ${wtoken}`);
  });


  function walkTrie(expectedRoot: string, path: string, proofNodesRlp: string) {
    let decode = ethers.utils.RLP.decode;
    let encode = ethers.utils.RLP.encode;
    let keccak256 = ethers.utils.keccak256;


    let nibblePath: Uint8Array = getNibbleArray(path);
    console.log(` path ${path} to nibbles ${nibblePath}`);
    let parentNodes = decode(proofNodesRlp);
    let nodeKey = expectedRoot;
    let pathPtr = 0;

    for(let i=0; i < parentNodes.length; i++) {
      let currentNode = encode(parentNodes[i]);
      let match = keccak256(currentNode) == nodeKey;
      console.log(`match ${match}`);

      let currentNodeList: any[] = parentNodes[i];
      if (currentNodeList.length == 17) {
        if(pathPtr == nibblePath.length) {
           return decode(currentNodeList[16]);
        }
        let nextPathNibble = nibblePath.at(pathPtr);
        nodeKey = currentNodeList[nextPathNibble];

        for(let j=0; j<currentNodeList.length; j++){
          if (i < parentNodes.length - 1 &&
            currentNodeList[j] == keccak256(encode(parentNodes[i+1]))) {
            console.log(`match for ${i} is ${j} but nextPathNibble is ${nextPathNibble}`);
          }
        }
        pathPtr++;

        // if (i < parentNodes.length - 1) {
          // let anyMatch = false;
          //   currentNodeList.some(node => {
          //   console.log(`${keccak256(encode(parentNodes[i + 1]))} == ${node}`);
          //   return keccak256(encode(parentNodes[i + 1])) == node;
          // })
          // console.log(`anyMatch ${anyMatch}`);
        // }

      } else if (currentNodeList.length == 2) {
        if(pathPtr == nibblePath.length) {
          return decode(currentNodeList[1]);
        }
        nodeKey = currentNodeList[1];
      }
    }

    console.log(`return`);
  }

  function getNibbleArray(path: string): Uint8Array {
    if (path.startsWith('0x')) {
      path = path.slice(2);
    }

    let buff = [path.length];
    for(let i = 0; i < path.length; i++){
      let nibbleStr = `0x${path.charAt(i)}`;
      buff[i] = parseInt(nibbleStr, 16);
    }

    return new Uint8Array(buff);
  }
});
