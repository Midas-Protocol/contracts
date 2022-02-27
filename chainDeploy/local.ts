import { SALT } from "../deploy/deploy";
import { ChainDeployConfig } from "./helper";
import { BigNumber } from "ethers";

export const deployConfig: ChainDeployConfig = {
  wtoken: "",
  nativeTokenName: "Ethereum (Local)",
  nativeTokenSymbol: "ETH",
  blocksPerYear: BigNumber.from((4 * 24 * 365 * 60).toString()),
};

export const deploy = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer, alice, bob } = await getNamedAccounts();

  ////
  //// IRM MODELS|
  let dep = await deployments.deterministic("JumpRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [
      deployConfig1337.blocksPerYear,
      "20000000000000000", // baseRatePerYear
      "180000000000000000", // multiplierPerYear
      "4000000000000000000", //jumpMultiplierPerYear
      "800000000000000000", // kink
    ],
    log: true,
  });

  const jrm = await dep.deploy();
  console.log("JumpRateModel: ", jrm.address);

  // taken from WhitePaperInterestRateModel used for cETH
  // https://etherscan.io/address/0x0c3f8df27e1a00b47653fde878d68d35f00714c0#code
  dep = await deployments.deterministic("WhitePaperInterestRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [
      deployConfig1337.blocksPerYear,
      "20000000000000000", // baseRatePerYear
      "100000000000000000", // multiplierPerYear
    ],
    log: true,
  });

  const wprm = await dep.deploy();
  console.log("WhitePaperInterestRateModel: ", wprm.address);
  ////

  ////
  //// TOKENS
  dep = await deployments.deterministic("TRIBEToken", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [ethers.utils.parseEther("1250000000"), deployer],
    log: true,
  });
  const tribe = await dep.deploy();
  console.log("TRIBEToken: ", tribe.address);
  const tribeToken = await ethers.getContractAt("TRIBEToken", tribe.address, deployer);
  let tx = await tribeToken.transfer(alice, ethers.utils.parseEther("100000"), { from: deployer });
  await tx.wait();

  tx = await tribeToken.transfer(bob, ethers.utils.parseEther("100000"), { from: deployer });
  await tx.wait();
  dep = await deployments.deterministic("TOUCHToken", {
    from: deployer,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [ethers.utils.parseEther("2250000000"), deployer],
    log: true,
  });
  const touch = await dep.deploy();
  const touchToken = await ethers.getContractAt("TOUCHToken", touch.address, deployer);
  tx = await touchToken.transfer(alice, ethers.utils.parseEther("100000"), { from: deployer });
  await tx.wait();

  tx = await touchToken.transfer(bob, ethers.utils.parseEther("100000"), { from: deployer });
  await tx.wait();
  ////

  ////
  //// ORACLES
  dep = await deployments.deterministic("SimplePriceOracle", {
    from: bob,
    salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
    args: [],
    log: true,
  });
  const simplePO = await dep.deploy();
  console.log("SimplePriceOracle: ", simplePO.address);

  const masterPriceOracle = await ethers.getContract("MasterPriceOracle", deployer);

  const simplePriceOracle = await ethers.getContract("SimplePriceOracle", deployer);

  // get the ERC20 address of deployed cERC20
  const underlyings = [tribe.address, touch.address];

  const admin = await masterPriceOracle.admin();
  if (admin === ethers.constants.AddressZero) {
    tx = await masterPriceOracle.initialize(
      underlyings,
      Array(underlyings.length).fill(simplePriceOracle.address),
      simplePO.address,
      deployer,
      true,
      ethers.constants.AddressZero
    );
    await tx.wait();
    console.log("MasterPriceOracle initialized", tx.hash);
  } else {
    console.log("MasterPriceOracle already initialized");
  }
  ////
};
