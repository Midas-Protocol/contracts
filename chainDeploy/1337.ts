import { SALT } from "../deploy/deploy";

export const deploy1337 = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer, alice, bob } = await getNamedAccounts();

  ////
  //// TOKENS
  let dep = await deployments.deterministic("TRIBEToken", {
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
