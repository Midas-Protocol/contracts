export const deploy1337 = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { deployer, alice, bob } = await getNamedAccounts();

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
};