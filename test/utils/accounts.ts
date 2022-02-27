const WHALE_ACCOUNTS = {
  56: "0x8894E0a0c962CB723c1976a4421c95949bE2D4E3", // binance hot wallet 6
};

export const whaleSigner = async (ethers) => {
  const { chainId } = await ethers.provider.getNetwork();
  const account = WHALE_ACCOUNTS[chainId];
  await ethers.provider.send("hardhat_impersonateAccount", [account]);
  return await ethers.getSigner(account);
};
