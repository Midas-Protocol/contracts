import {deployments, ethers} from "hardhat";
import { expect } from "chai";
import {getOrCreateFuse} from "./utils/fuseSdk";
import { Fuse } from "../src";

describe("Verify the ERC20 functionality", () => {
  let sdk: Fuse;

  beforeEach(async () => {
    await deployments.fixture("prod");
    sdk = await getOrCreateFuse();
  });

  it("should allow approve/transferFrom in a single tx with permit", async function () {
    const { alice } = await ethers.getNamedSigners();

    let spender = alice.address;
    let amountToApprove = 1e8;
    let block = await ethers.provider.getBlock('latest');
    let futureTimestamp = block.timestamp + 10;

    // use a different private key than deployer to check that any msg.sender set approvals with a signed permit
    const signingKey = new ethers.utils.SigningKey("0xCAFE");
    let signingAddress = ethers.utils.computeAddress(signingKey.publicKey);

    const touchToken = await ethers.getContractAt("TOUCHToken", sdk.chainDeployment.TOUCHToken.address);

    // construct the permit call hash, then sign it
    const PERMIT_TYPEHASH = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    );
    let domainSep = await touchToken.callStatic.DOMAIN_SEPARATOR();
    let innerTypes = ["bytes32", "address", "address", "uint256", "uint256", "uint256"];
    let innerValues = [PERMIT_TYPEHASH, signingAddress, spender, amountToApprove, 0, futureTimestamp];
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
    let permitHash = ethers.utils.keccak256(packed);
    let { v, r, s } = signingKey.signDigest(permitHash);

    await touchToken.permit(signingAddress, spender, amountToApprove, futureTimestamp, v, r, s);

    let allowance = await touchToken.callStatic.allowance(signingAddress, spender);
    expect(allowance).to.eq(amountToApprove);
  });
});
