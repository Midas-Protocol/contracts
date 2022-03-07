import { task, types } from "hardhat/config";
import { MasterPriceOracle, UniswapTwapPriceOracleV2Factory } from "../typechain";

export default task("oracle:set-price", "Set price of token")
  .addOptionalParam("token", "Token for which to set the price", undefined, types.string)
  .addOptionalParam("address", "Token address for which to set the price", undefined, types.string)
  .addParam("price", "Address to which the minted tokens should be sent to")
  .setAction(async ({ token: _token, address: _address, price: _price }, { getNamedAccounts, ethers }) => {
    const oracleModule = await import("../test/utils/oracle");

    const [tokenAddress, oracle] = await oracleModule.setUpOracleWithToken(_token, _address, ethers, getNamedAccounts);
    const tx = await oracle.setDirectPrice(tokenAddress, ethers.utils.parseEther(_price));
    await tx.wait();
    console.log(`Set price of ${_token ? _token : _address} to ${_price}`);
  });

task("oracle:get-price", "Get price of token")
  .addOptionalParam("token", "Token for which to set the price", undefined, types.string)
  .addOptionalParam("address", "Token address for which to set the price", undefined, types.string)
  .setAction(async ({ token: _token, address: _address, price: _price }, { getNamedAccounts, ethers }) => {
    const oracleModule = await import("../test/utils/oracle");
    const [tokenAddress, oracle] = await oracleModule.setUpOracleWithToken(_token, _address, ethers, getNamedAccounts);
    const tokenPrice = await oracle.callStatic.assetPrices(tokenAddress);
    console.log(`Price ${_token}: ${ethers.utils.formatEther(tokenPrice)}`);
    return tokenPrice;
  });

task("oracle:add-tokens", "Initalize MasterPriceOracle with underlying oracle for assets")
  .addOptionalParam("underlyings", "Token for which to set the price", undefined, types.string)
  .addOptionalParam("oracles", "Token address for which to set the price", undefined, types.string)
  .setAction(async ({ underlyings: _underlyings, oracles: _oracles }, { getNamedAccounts, ethers }) => {
    const { deployer } = await ethers.getNamedSigners();
    const sdkModule = await import("../dist/esm/src");
    const { chainId } = await ethers.provider.getNetwork();
    const sdk = new sdkModule.Fuse(ethers.provider, chainId);

    const spo = (await ethers.getContract("MasterPriceOracle", deployer)) as MasterPriceOracle;
    const underlyingTokens = _underlyings.split(",");

    let underlyingOracles: Array<string>;

    if (!_oracles) {
      // by default, get uniswap's twap oracle address
      const uniOralceFactory = (await ethers.getContract(
        "UniswapTwapPriceOracleV2Factory",
        deployer
      )) as UniswapTwapPriceOracleV2Factory;
      const underlyingOracle = await uniOralceFactory.callStatic.oracles(
        sdk.chainSpecificAddresses.UNISWAP_V2_FACTORY,
        sdk.chainSpecificAddresses.W_TOKEN
      );
      underlyingOracles = Array(underlyingTokens.length).fill(underlyingOracle);
    } else {
      underlyingOracles = _oracles.split(",");
      if (underlyingOracles.length === 1) {
        underlyingOracles = Array(underlyingTokens.length).fill(underlyingOracles);
      }
    }
    const tx = await spo.add(underlyingTokens, underlyingOracles);
    await tx.wait();
    console.log(`Master Price Oracle updated for tokens ${underlyingTokens.join(", ")}`);
  });
