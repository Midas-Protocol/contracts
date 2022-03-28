import { constants } from "ethers";
import { getChainId } from "hardhat";
import { Fuse } from "../../src";

export const setUpOracleWithToken = async (_token, _address, ethers, getNamedAccounts) => {
  const { deployer } = await getNamedAccounts();
  const signer = await ethers.getSigner(deployer);
  const chainId = await getChainId();
  const sdk = new Fuse(ethers.provider, Number(chainId));
  const mpo = await ethers.getContractAt("MasterPriceOracle", sdk.oracles.MasterPriceOracle.address, signer);

  if (_address) {
    return [_address, mpo];
  }
  if (_token === "ETH") {
    return [constants.AddressZero, mpo];
  } else {
    const token = await ethers.getContract(`${_token}Token`);
    return [token.address, mpo];
  }
};
