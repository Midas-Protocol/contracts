import { run } from "hardhat";
import hre from "hardhat";

import { writeFile } from "./util";
import { Fuse } from "../lib/esm";

async function main() {
  await run("compile");
  const compiledContracts = {
    contracts: {},
  };

  const paths = await hre.artifacts.getAllFullyQualifiedNames();

  const oraclesRegex = new RegExp("contracts/oracles($|/.*)");
  const oracleContracts = paths.filter((p) => p.match(oraclesRegex)).filter((n) => n);

  oracleContracts.map((fullyQualifiedName) => {
    const artifact = hre.artifacts.readArtifactSync(fullyQualifiedName);
    compiledContracts.contracts[artifact.contractName] = {
      abi: artifact.abi,
      bytecode: artifact.bytecode,
    };
  });

  const spo = hre.artifacts.readArtifactSync("SimplePriceOracle");
  compiledContracts.contracts["SimplePriceOracle"] = {
    abi: spo.abi,
    bytecode: spo.bytecode,
  };

  // wen JS Set.intersection/symmetric difference ?
  const A = Fuse.ORACLES;
  const B = Object.keys(compiledContracts.contracts);

  const diffA = A.filter((x) => !B.includes(x));
  const diffB = B.filter((x) => !A.includes(x));

  if (diffA.length > 0) {
    console.warn(`SDK-defined contracts not found in Compiled contracts:\n- ${diffA.join("\n- ")}`);
  }
  if (diffB.length > 0) {
    console.warn(`Compiled contracts not found in SDK-defined contracts: \n- ${diffB.join("\n- ")}`);
  }

  await writeFile("./src/Fuse/contracts/" + "oracles.min.json", JSON.stringify(compiledContracts));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
