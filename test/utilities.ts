import { ethers } from "hardhat";
import { ContractConfig } from "../lib/esm";
import * as fs from "fs";
import * as path from "path";

export const ETH_ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

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

export async function getContractsConfig(network: string, thisObject?: Object): Promise<ContractConfig> {
  const basePath = __dirname + "/../";
  if (network === "hardhat" || network === "development" || network == "localhost") {
    return await createLocalContractConfig();
  }
  return await readFile(getNetworkPath(basePath, network), parseNetworkFile);
}

async function createLocalContractConfig(): Promise<ContractConfig> {
  return {
    TOKEN_ADDRESS: { DAI_JUG: "", DAI_POT: "", USDC: "", W_TOKEN: "" },
    COMPOUND_CONTRACT_ADDRESSES: {
      Comptroller: (await ethers.getContract("Comptroller")).address, // comp.address,
      CErc20Delegate: (await ethers.getContract("CErc20Delegate")).address, // cErc20Delegate,
      CEtherDelegate: (await ethers.getContract("CEtherDelegate")).address, //cEtherDelegate,
      InitializableClones: "",
      RewardsDistributorDelegate: "",
    },
    FUSE_CONTRACT_ADDRESSES: {
      FusePoolDirectory: (await ethers.getContract("FusePoolDirectory")).address, // fpd.address,
      FuseFeeDistributor: (await ethers.getContract("FuseFeeDistributor")).address, // ffd.address,
      FusePoolLens: (await ethers.getContract("FusePoolLens")).address, //fpl.address,
      FusePoolLensSecondary: (await ethers.getContract("FusePoolLensSecondary")).address, //fpl.address,
      FuseSafeLiquidator: (await ethers.getContract("FuseSafeLiquidator")).address, //fpls.address,
      MasterPriceOracleImplementation: "",
    },
    PUBLIC_INTEREST_RATE_MODEL_CONTRACT_ADDRESSES: {
      WhitePaperInterestRateModel: (await ethers.getContract("WhitePaperInterestRateModel")).address,
      JumpRateModel: (await ethers.getContract("JumpRateModel")).address,
    },
    PRICE_ORACLE_RUNTIME_BYTECODE_HASHES: {
      UniswapV2_PairInit: "",
    },
    PUBLIC_PRICE_ORACLE_CONTRACT_ADDRESSES: {
      MasterPriceOracle: (await ethers.getContract("MasterPriceOracle")).address,
    },
    FACTORY: {
      UniswapV2_Factory: "",
      UniswapV3TwapPriceOracleV2_Factory: "",
      UniswapTwapPriceOracleV2_Factory: "",
    },
  };
}
