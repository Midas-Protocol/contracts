import { ethers } from "hardhat";
import { contractConfig } from "../lib/esm";
import * as fs from "fs";
import * as path from "path";

export async function prepare(thisObject, contracts) {
  thisObject.signers = await ethers.getSigners();
  thisObject.deployer = thisObject.signers[0];
  thisObject.alice = thisObject.signers[1];
  thisObject.bob = thisObject.signers[2];
  thisObject.carol = thisObject.signers[3];

  for (let i in contracts) {
    let contract = contracts[i];
    thisObject[contract[0]] = await ethers.getContractFactory(
      contract[0],
      contract[1] ? thisObject[contract[1]] : thisObject.deployer
    );
  }
}

export async function deploy(thisObject, contracts) {
  for (let i in contracts) {
    let contract = contracts[i];
    thisObject[contract[0]] = await contract[1].deploy(...(contract[2] || []));
    await thisObject[contract[0]].deployed();
  }
}

export async function initializeWithWhitelist(thisObject, accounts?: Array<string>) {
  if (accounts == null) {
    accounts = thisObject.signers.slice(1, 4).map((d) => d.address);
  }

  const tx = await thisObject.fpd.initialize(true, accounts);
  await tx.wait();
  const isWhitelisted = await Promise.all(accounts.map(async (d) => await thisObject.fpd.deployerWhitelist(d)));
  console.log(
    "Whitelisted addresses: ",
    isWhitelisted.map((v, i) => `${accounts[i]}: ${v}`)
  );
}

export function getNetworkPath(basePath: string | null, network: string, extension: string | null = "json"): string {
  return path.join(basePath || "", "network", `${network}${extension ? `.${extension}` : ""}`);
}

export async function readFile<T>(file: string, fn: (data: string) => T): Promise<T> {
  return new Promise((resolve, reject) => {
    fs.access(file, fs.constants.F_OK, (err) => {
      if (err) {
        console.log(`Error reading file ${err}`);
      } else {
        fs.readFile(file, "utf8", (err, data) => {
          return err ? reject(err) : resolve(fn(data));
        });
      }
    });
  });
}

function parseNetworkFile(data: string | object) {
  return typeof data === "string" ? JSON.parse(data) : data;
}

export async function getContractsConfig(network: string, thisObject?: Object): Promise<contractConfig> {
  const basePath = __dirname + "/../";
  if (network === "hardhat" || network === "development" || network == "localhost") {
    return await createLocalContractConfig();
  }
  return await readFile(getNetworkPath(basePath, network), parseNetworkFile);
}

async function createLocalContractConfig(): Promise<contractConfig> {
  return {
    TOKEN_ADDRESS: { DAI_JUG: "", DAI_POT: "", USDC: "", W_TOKEN: "" },
    COMPOUND_CONTRACT_ADDRESSES: {
      Comptroller: "0x7AD018c7d6217f37B0121AdA46AC4e99Ab8dd8C1", // comp.address,
      CErc20Delegate: "0xFdB32Ead5e92e81d3A90B09Ca8021088aD0975E9", // cErc20Delegate,
      CEther20Delegate: "0xff8F1382a78A7b910E516508D1CC934bbA08208f", //cEther20Delegate,
      InitializableClones: "",
      RewardsDistributorDelegate: "",
    },
    FUSE_CONTRACT_ADDRESSES: {
      FusePoolDirectory: "0x5E5be5aAF574fBB4f66Da933A06DD31DeD748E52", // fpd.address,
      FuseFeeDistributor: "0x3f739767fdaF80020f6A407a92866DD884810cFc", // ffd.address,
      FusePoolLens: "0xefF651143CceF7FcB8C73cF5F0F18b887aceB22F", //fpl.address,
      FusePoolLensSecondary: "0x954FAd8bCb920FD2D8f9f0dBd6269E7ffC68F1A5", //fpl.address,
      FuseSafeLiquidator: "0xc292D493f6CE7245a41bA414C6494Fa01B6C6E3F", //fpls.address,
      MasterPriceOracleImplementation: "",
    },
    PUBLIC_INTEREST_RATE_MODEL_CONTRACT_ADDRESSES: {},
    PRICE_ORACLE_RUNTIME_BYTECODE_HASHES: {
      UniswapV2_PairInit: "",
    },
    PUBLIC_PRICE_ORACLE_CONTRACT_ADDRESSES: {},
    FACTORY: {
      UniswapV2_Factory: "",
      UniswapV3TwapPriceOracleV2_Factory: "",
      UniswapTwapPriceOracleV2_Factory: "",
    },
  };
}
