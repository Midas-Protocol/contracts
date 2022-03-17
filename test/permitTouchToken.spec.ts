import {deployments, ethers} from "hardhat";
import {Fuse} from "../dist/esm/src";
import {computeAddress} from "@ethersproject/transactions/src.ts/index";

describe.only("Verify the ERC20 functionality", () => {
  beforeEach(async () => {
    await deployments.fixture(); // ensure you start from a fresh deployments
  });

  it("should allow approve/transferFrom in a single tx with permit", async function () {
    const { chainId } = await ethers.provider.getNetwork();
    const sdk = new Fuse(ethers.provider, chainId);
    const { alice, bob } = await ethers.getNamedSigners();
    let spender = alice.address;

    let block = await ethers.provider.getBlock('latest');

    const touchToken = await ethers.getContractAt("TOUCHToken", sdk.chainDeployment.TOUCHToken.address);
    console.log(`touchToken.address ${touchToken.address}`);
    console.log(await touchToken.callStatic.name());

    const PERMIT_TYPEHASH = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    );
    console.log(`PERMIT_TYPEHASH ${PERMIT_TYPEHASH}`);

    const signingKey = new ethers.utils.SigningKey("0xCAFE");
    let signingAddress = ethers.utils.computeAddress(signingKey.publicKey);

    let domainSep = await touchToken.callStatic.DOMAIN_SEPARATOR();
    console.log(`DOMAIN_SEPARATOR ${domainSep}`);

    let innerTypes = ["bytes32", "address", "address", "uint256", "uint256", "uint256"];
    let innerValues = [PERMIT_TYPEHASH, signingAddress, spender, 1e8, 0, block.timestamp + 10];
    let outerTypes = ["bytes1", "bytes1", "bytes32", "bytes32"];
    let outerValues = [
      "0x19", "0x01",
      domainSep,
      ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          innerTypes,
          innerValues
        )
      )
    ];

    let packed = ethers.utils.solidityPack(outerTypes, outerValues);
    console.log(`packed ${packed}`);

    let permitHash = ethers.utils.keccak256(packed);
    console.log(`solidityPack keccak256 permitHash ${permitHash}`);
    // let solidityKeccak256PermitHash = ethers.utils.solidityKeccak256(outerTypes, outerValues);
    // console.log(`solidityKeccak256 PermitHash ${solidityKeccak256PermitHash}`);

    // F.M.L.
    // We use ethers.utils.SigningKey for a Wallet instead of
    // Signer.signMessage to do not add '\x19Ethereum Signed Message:\n'
    // prefix to the signed message. The '\x19` protection (see EIP191 for
    // more details on '\x19' rationale and format) is already included in
    // EIP2612 permit signed message and '\x19Ethereum Signed Message:\n'
    // should not be used there.
    // let signedHash = await bob.signMessage(permitHash);

    let sig = signingKey.signDigest(permitHash);
    // console.log(`signedHash ${signedHash}`);
    console.log(`signingAddress ${signingAddress}`);

    // let sig = ethers.utils.splitSignature(signedHash);
    let { v, r, s } = sig;

    console.log(`
    v ${v} 
    r ${r} 
    s ${s}
    `);


    let recovered = ethers.utils.recoverAddress(permitHash, sig);
    console.log(`rec ${recovered} signingAddress ${signingAddress}`);

    await touchToken.permit(signingAddress, spender, 1e8, block.timestamp + 10, v, r, s);

    let allowance = await touchToken.callStatic.allowance(signingAddress, spender);

    console.log(`allowance ${allowance}`);
  });
});
