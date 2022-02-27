import { cERC20Conf } from "../../lib/esm/src";

export const getLocalAssetsConf = async (comptroller, interestRateModelAddress, ethers) => {
  const ethConf: cERC20Conf = {
    underlying: "0x0000000000000000000000000000000000000000",
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Ethereum",
    symbol: "ETH",
    decimals: 18,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 20,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };

  const tribeConf: cERC20Conf = {
    underlying: await ethers.getContract("TRIBEToken").then((c) => c.address),
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "TRIBE Token",
    symbol: "TRIBE",
    decimals: 18,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 15,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };
  const touchConf: cERC20Conf = {
    underlying: await ethers.getContract("TOUCHToken").then((c) => c.address),
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Midas TOUCH Token",
    symbol: "TOUCH",
    decimals: 18,
    admin: "true",
    collateralFactor: 65,
    reserveFactor: 20,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };
  return [ethConf, tribeConf, touchConf];
};

export const getBscAssetsConf = async (comptroller, interestRateModelAddress, bscAssets) => {
  const btc = bscAssets.find((b) => b.symbol === "BTCB");
  const busd = bscAssets.find((b) => b.symbol === "BUSD");
  const bnbConf: cERC20Conf = {
    underlying: "0x0000000000000000000000000000000000000000",
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: "Binance Coin",
    symbol: "BNB",
    decimals: 18,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 20,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };
  const btcConf: cERC20Conf = {
    underlying: btc.underlying,
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: btc.name,
    symbol: btc.symbol,
    decimals: btc.decimals,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 15,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };
  const busdConf: cERC20Conf = {
    underlying: busd.underlying,
    comptroller,
    interestRateModel: interestRateModelAddress,
    name: busd.name,
    symbol: busd.symbol,
    decimals: busd.decimals,
    admin: "true",
    collateralFactor: 75,
    reserveFactor: 15,
    adminFee: 0,
    bypassPriceFeedCheck: true,
  };
  return [bnbConf, btcConf, busdConf];
};
