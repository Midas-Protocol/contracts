import { ethers } from "hardhat";
import * as fs from "fs";

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
