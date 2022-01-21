export const deploy1337 = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer, alice, bob } = await getNamedAccounts();

  //// 
  //// TOKENS
  let dep = await deployments.deterministic("TRIBEToken", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
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
    salt: ethers.utils.keccak256(deployer),
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
  dep = await deployments.deterministic("MockPriceOracle", {
    from: bob,
    salt: ethers.utils.keccak256(deployer),
    args: [100],
    log: true,
  });
  const mockPO = await dep.deploy();
  console.log("MockPriceOracle: ", mockPO.address);

  const masterPriceOracle = await ethers.getContract("MasterPriceOracle", deployer);

  // if chain id 1337
  const mockPriceOracle = await ethers.getContract("MockPriceOracle", deployer);

  // get the ERC20 address of deployed cERC20
  const underlyings = [
    tribe.address,
    touch.address,
  ];

  tx = await masterPriceOracle.initialize(
    underlyings,
    Array(underlyings.length).fill(mockPriceOracle.address),
    mockPriceOracle.address,
    deployer,
    true
  );
  await tx.wait();
  console.log("Initialized MasterPriceOracle for chain 1337");
  ////
};