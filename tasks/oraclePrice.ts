import {subtask, task} from "hardhat/config";
import * as OracleSdk from '@keydonix/uniswap-oracle-sdk'
import * as OracleSdkAdapter from '@keydonix/uniswap-oracle-sdk-adapter'
import {Contract} from "ethers";
import {ethers} from "hardhat";

export default task("set-price", "Set price of token")
  .addParam("token", "Token for which to set the price")
  .addParam("price", "Address to which the minted tokens should be sent to")
  .setAction(async ({ token: _token, price: _price }, { getNamedAccounts, ethers }) => {
    const oracleModule = await import("../test/utils/oracle");
    const [tokenAddress, oracle] = await oracleModule.setUpOracleWithToken(_token, ethers, getNamedAccounts);
    const tx = await oracle.setDirectPrice(tokenAddress, ethers.utils.parseEther(_price));
    await tx.wait();
    console.log(`Set price of ${_token} to ${_price}`);
  });

task("get-price", "Get price of token")
    .addParam("token", "Token for which to get the price")
    .setAction(async ({ token: _token }, { getNamedAccounts, ethers }) => {
        const oracleModule = await import("../test/utils/oracle");
        const [tokenAddress, oracle] = await oracleModule.setUpOracleWithToken(_token, ethers, getNamedAccounts);
        const tokenPrice = await oracle.callStatic.assetPrices(tokenAddress);
        console.log(`Price ${_token}: ${ethers.utils.formatEther(tokenPrice)}`);
        return tokenPrice;
    });
