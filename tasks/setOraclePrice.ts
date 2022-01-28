import { task } from "hardhat/config";
import { constants } from "ethers";

export default task("set-price", "Set price of token")
  .addParam("token", "Token for which to set the price")
  .addParam("price", "Address to which the minted tokens should be sent to")
  .setAction(async ({ token: _token, price: _price }, { getNamedAccounts, ethers }) => {
    let tokenAddress;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.getSigner(deployer);
    const spo = await ethers.getContract("SimplePriceOracle", signer);
    if (_token === "ETH") {
      tokenAddress = constants.AddressZero;
    } else {
      const token = await ethers.getContract(`${_token}Token`);
      tokenAddress = token.address;
    }
    await spo.setDirectPrice(tokenAddress, ethers.utils.parseEther(_price));
  });
