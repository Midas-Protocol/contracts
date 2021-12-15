import { run } from "hardhat";
import hre from "hardhat";
import * as fs from "fs";

export async function writeFile<T>(file: string, data: string): Promise<any> {
  return new Promise((resolve, reject) => {
    fs.writeFile(file, data, (err) => {
      return err ? reject(err) : console.log(err); // XXXS `!`
    });
  });
}

async function main() {
  await run("compile");
  const compiledContracts = {
    contracts: {},
  };
  const paths = await hre.artifacts.getAllFullyQualifiedNames();
  const compoundRegex = new RegExp("contracts/compound($|/.*)");
  const compoundContracts = paths.filter((p) => p.match(compoundRegex)).filter((n) => n);

  compoundContracts.map((fullyQualifiedName) => {
    const basePath = fullyQualifiedName.replace("/compound/", "/");
    const artifact = hre.artifacts.readArtifactSync(fullyQualifiedName);
    compiledContracts.contracts[basePath] = {
      abi: artifact.abi,
      bytecode: artifact.bytecode,
    };
  });
  await writeFile("./out/" + "compound-protocol.json", JSON.stringify(compiledContracts));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
