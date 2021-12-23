import { run } from "hardhat";
import hre from "hardhat";
import { writeFile } from "./util";

const FUSE_CONTRACTS = [
  "FuseFeeDistributor",
  "FusePoolDirectory",
  "FusePoolLens",
  "FusePoolLensSecondary",
  "FuseSafeLiquidator",
  "InitializableClones",
];

async function main() {
  await run("compile");
  const filesToWrite = [];
  const paths = await hre.artifacts.getAllFullyQualifiedNames();

  FUSE_CONTRACTS.map((c) => {
    const contract = c + `.sol:${c}`;
    const desiredContract = paths.filter((p) => p.replace(/^.*[\\\/]/, "") === contract)[0];
    const artifact = hre.artifacts.readArtifactSync(desiredContract);
    filesToWrite.push(writeFile("./src/Fuse/abi/" + c + ".json", JSON.stringify(artifact.abi)));
  });
  await Promise.all(filesToWrite);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
