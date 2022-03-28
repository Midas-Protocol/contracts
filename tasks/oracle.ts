import { task, types } from "hardhat/config";

export default task("oracle:set-price", "Set price of token")
  .addOptionalParam("token", "Token for which to set the price", undefined, types.string)
  .addOptionalParam("address", "Token address for which to set the price", undefined, types.string)
  .addParam("price", "Address to which the minted tokens should be sent to")
  .setAction(async ({ token: _token, address: _address, price: _price }, { getNamedAccounts, ethers }) => {
    const { deployer } = await ethers.getNamedSigners();
    const oracleModule = await import("../test/utils/oracle");

    const [tokenAddress, oracle] = await oracleModule.setUpOracleWithToken(_token, _address, ethers, getNamedAccounts);
    const underlyingOracle = await ethers.getContractAt(
      "SimplePriceOracle",
      await oracle.callStatic.oracles(tokenAddress),
      deployer
    );
    const tx = await underlyingOracle.setDirectPrice(tokenAddress, ethers.utils.parseEther(_price));
    await tx.wait();
    console.log(`Set price of ${_token ? _token : _address} to ${_price}`);
  });

task("oracle:get-price", "Get price of token")
  .addOptionalParam("token", "Token for which to set the price", undefined, types.string)
  .addOptionalParam("address", "Token address for which to set the price", undefined, types.string)
  .setAction(async ({ token: _token, address: _address, price: _price }, { getNamedAccounts, ethers }) => {
    const oracleModule = await import("../test/utils/oracle");
    const [tokenAddress, oracle] = await oracleModule.setUpOracleWithToken(_token, _address, ethers, getNamedAccounts);
    const tokenPriceMPO = await oracle.price(tokenAddress);
    console.log(`Price ${_token ? _token : _address}: ${ethers.utils.formatEther(tokenPriceMPO)}`);
    return tokenPriceMPO;
  });

task("oracle:add-tokens", "Initalize MasterPriceOracle with underlying oracle for assets")
  .addOptionalParam("underlyings", "Token for which to set the price", undefined, types.string)
  .addOptionalParam("oracles", "Token address for which to set the price", undefined, types.string)
  .setAction(async ({ underlyings: _underlyings, oracles: _oracles }, { ethers }) => {
    const { deployer } = await ethers.getNamedSigners();
    // @ts-ignore
    const sdkModule = await import("../dist/esm/src");
    const { chainId } = await ethers.provider.getNetwork();
    const sdk = new sdkModule.Fuse(ethers.provider, chainId);

    const mpo = await ethers.getContractAt("MasterPriceOracle", sdk.oracles.MasterPriceOracle.address, deployer);
    const underlyingTokens = _underlyings.split(",");

    let underlyingOracles: Array<string>;

    if (!_oracles) {
      // by default, get uniswap's twap oracle address
      const uniOracleFactory = await ethers.getContractAt(
        "UniswapTwapPriceOracleV2Factory",
        sdk.chainDeployment.UniswapTwapPriceOracleV2Factory.address,
        deployer
      );
      const underlyingOracle = await uniOracleFactory.callStatic.oracles(
        sdk.chainSpecificAddresses.UNISWAP_V2_FACTORY,
        sdk.chainSpecificAddresses.W_TOKEN
      );
      underlyingOracles = Array(underlyingTokens.length).fill(underlyingOracle);
    } else {
      underlyingOracles = _oracles.split(",");
      if (underlyingOracles.length === 1) {
        underlyingOracles = Array(underlyingTokens.length).fill(underlyingOracles[0]);
      }
    }
    const tx = await mpo.add(underlyingTokens, underlyingOracles);
    await tx.wait();
    console.log(`Master Price Oracle updated for tokens ${underlyingTokens.join(", ")}`);
  });

task("oracle:update-twap", "Call update on twap oracle to update the last price observation")
  .addParam("pair", "pair address for which to run the update", undefined, types.string)
  .setAction(async ({ pair: _pair }, { run, ethers }) => {
    const { deployer } = await ethers.getNamedSigners();

    // @ts-ignore
    const sdkModule = await import("../dist/esm/src");
    const { chainId } = await ethers.provider.getNetwork();
    const sdk = new sdkModule.Fuse(ethers.provider, chainId);

    const uniswapTwapRoot = await ethers.getContract("UniswapTwapPriceOracleV2Root", deployer);
    const uniPair = new ethers.Contract(
      _pair,
      ["function token0() external view returns (address)", "function token1() external view returns (address)"],
      deployer
    );
    const token0 = await uniPair.callStatic.token0();
    const token1 = await uniPair.callStatic.token1();
    const token = sdk.chainSpecificAddresses.W_TOKEN === token0 ? token1 : token0;

    await run("oracle:get-price", { address: token });

    const tx = await uniswapTwapRoot["update(address)"](_pair);
    await tx.wait();

    await run("oracle:get-price", { address: token });
  });
