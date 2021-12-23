import { run } from "hardhat";
import hre from "hardhat";
import { writeFile } from "./util";

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
  await writeFile("./src/Fuse/contracts/" + "compound-protocol.json", JSON.stringify(compiledContracts));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
