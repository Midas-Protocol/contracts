import { task } from "hardhat/config";
import { constants } from "ethers";

const setUpOracleWithToken = async (_token, ethers, getNamedAccounts) => {
  const { deployer } = await getNamedAccounts();
  const signer = await ethers.getSigner(deployer);
  const spo = await ethers.getContract("SimplePriceOracle", signer);

  if (_token === "ETH") {
    return [constants.AddressZero, spo];
  } else {
    const token = await ethers.getContract(`${_token}Token`);
    return [token.address, spo];
  }
};

export default task("set-price", "Set price of token")
  .addParam("token", "Token for which to set the price")
  .addParam("price", "Address to which the minted tokens should be sent to")
  .setAction(async ({ token: _token, price: _price }, { getNamedAccounts, ethers }) => {
    const [tokenAddress, oracle] = await setUpOracleWithToken(_token, ethers, getNamedAccounts);
    const tx = await oracle.setDirectPrice(tokenAddress, ethers.utils.parseEther(_price));
    await tx.wait();
    console.log(`Set price of ${_token} to ${_price}`);
  });

task("get-price", "Get price of token")
  .addParam("token", "Token for which to set the price")
  .setAction(async ({ token: _token }, { getNamedAccounts, ethers }) => {
    const [tokenAddress, oracle] = await setUpOracleWithToken(_token, ethers, getNamedAccounts);
    const tokenPrice = await oracle.callStatic.assetPrices(tokenAddress);
    console.log(`Price ${_token}: ${tokenPrice}`);
    return tokenPrice;
  });
