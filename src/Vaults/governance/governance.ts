import axios from "axios";

// ABIs
import ERC20ABI from '../abi/ERC20.json'
import RariGovernanceToken from './abi/RariGovernanceToken.json'
import RariGovernanceTokenDistributor from './abi/RariGovernanceTokenDistributor.json'
import RariGovernanceTokenVesting from './abi/RariGovernanceTokenVesting.json'
import RariGovernanceTokenUniswapDistributor from './abi/RariGovernanceTokenUniswapDistributor.json'

// Ethers
import { JsonRpcProvider } from "@ethersproject/providers";
import { Contract } from "@ethersproject/contracts";
import { utils, BigNumber, constants } from "ethers";

// Cache
import Cache from "../cache";

export const contractAddresses = {
    RariGovernanceToken: "0xD291E7a03283640FDc51b121aC401383A46cC623",
    RariGovernanceTokenDistributor: "0x9C0CaEb986c003417D21A7Daaf30221d61FC1043",
    RariGovernanceTokenUniswapDistributor: "0x1FA69a416bCF8572577d3949b742fBB0a9CD98c7",
    RariGovernanceTokenVesting: "0xA54B473028f4ba881F1eD6B670af4103e8F9B98a",
  };

export const abis = {
    RariGovernanceToken,
    RariGovernanceTokenDistributor,
    RariGovernanceTokenUniswapDistributor,
    RariGovernanceTokenVesting
}
 
export const LP_TOKEN_CONTRACT = "0x18a797c7c70c1bf22fdee1c09062aba709cacf04";

export default class Governance {
    provider: JsonRpcProvider
    cache: Cache
    contracts: {[key: string]: Contract}
    rgt: {
      distributions,
      getExchangeRate
      sushiSwapDistributions,
      vesting: {
        PRIVATE_VESTING_START_TIMESTAMP,
        PRIVATE_VESTING_PERIOD,
        getUnclaimed: (account: any) => Promise<BigNumber>,
        claim,
        claimAll,
        getClaimFee: (timestamp: number) => BigNumber

      },
      balanceOf,
      transfer
    }
    API_BASE_URL = "https://api.rari.capital/governance/";
    static CONTRACT_ADDRESSES = contractAddresses;
    static CONTRACT_ABIS = abis;


    constructor(provider: JsonRpcProvider) {
        this.provider = provider
        this.cache = new Cache({ rgtUsdPrice: 900, lpTokenData: 900 });

        this.contracts = {
          RariGovernanceToken: new Contract(contractAddresses["RariGovernanceToken"], abis["RariGovernanceToken"], this.provider),
          RariGovernanceTokenDistributor: new Contract(contractAddresses["RariGovernanceTokenDistributor"], abis["RariGovernanceTokenDistributor"], this.provider),
          RariGovernanceTokenUniswapDistributor: new Contract(contractAddresses["RariGovernanceTokenUniswapDistributor"], abis["RariGovernanceTokenUniswapDistributor"], this.provider),
          RariGovernanceTokenVesting: new Contract(contractAddresses["RariGovernanceTokenVesting"], abis["RariGovernanceTokenVesting"], this.provider),
        }

        const self = this

        const distributionStartBlock = 11094200
        const distributionPeriod = 390000
        const distributionEndBlock = distributionStartBlock - distributionPeriod
        const finalRGTDistribution= BigNumber.from("8750000000000000000000000")

        this.rgt = {
            getExchangeRate: async function () {
                return await self.cache.getOrUpdate("rgtUsdPrice", async function () {
                    /* try {
                      return Web3.utils.toBN(Math.trunc((await axios.get("https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=rgt")).data.rgt.usd * 1e18));
                    } catch (error) {
                      throw new Error("Error retrieving data from Coingecko API: " + error);
                    } */
          
                    try {
                      var data = (
                        await axios.post(
                          "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v2",
                          {
                            query: `{
                        ethRgtPair: pair(id: "0xdc2b82bc1106c9c5286e59344896fb0ceb932f53") {
                          token0Price
                        }
                        ethUsdtPair: pair(id: "0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852") {
                          token1Price
                        }
                      }
                      `,
                          }
                        )
                      ).data;
          
                      return utils.parseUnits(
                        (data.data.ethRgtPair.token0Price * data.data.ethUsdtPair.token1Price).toString()
                      );
                    } catch (error) {
                      throw new Error(
                        "Error retrieving data from The Graph API: " + error
                      );
                    }
                  });
            },
            distributions: {
                getDistributedAtBlock: function (blockNumber: number) {
                  const startBlock = distributionStartBlock

                  if (blockNumber <= startBlock) return constants.Zero;

                  if ( blockNumber >= startBlock + distributionPeriod ) return finalRGTDistribution;

                  const blocks = blockNumber - startBlock;
                    const blocksBN = BigNumber.from(blocks)

                  if (blocks < 6500 * 15)
                    return constants.WeiPerEther
                      .mul(blocksBN.pow(BigNumber.from(2)))
                      .div(BigNumber.from(2730))
                      .add(
                        BigNumber.from("1450000000000000000000").mul(blocksBN).div(BigNumber.from(273))
                      );
                  if (blocks < 6500 * 30)
                    return BigNumber.from("14600000000000000000000")
                      .mul(blocksBN)
                      .div(BigNumber.from(273))
                      .sub(
                        BigNumber.from("2000000000000000000")
                          .mul(blocksBN.pow(BigNumber.from(2)))
                          .div(BigNumber.from(17745))
                      )
                      .sub(BigNumber.from("1000000000000000000000000").div(BigNumber.from(7)));
                  if (blocks < 6500 * 45)
                    return constants.WeiPerEther
                      .mul(blocksBN.pow(BigNumber.from(2)))
                      .div(BigNumber.from(35490))
                      .add(BigNumber.from("39250000000000000000000000").div(BigNumber.from(7)))
                      .sub(
                        BigNumber.from("950000000000000000000").mul(blocksBN).div(BigNumber.from(273))
                      );
                  return constants.WeiPerEther
                    .mul(blocksBN.pow(BigNumber.from(2)))
                    .div(BigNumber.from(35490))
                    .add(BigNumber.from("34750000000000000000000000").div(BigNumber.from(7)))
                    .sub(BigNumber.from("50000000000000000000").mul(blocksBN).div(BigNumber.from(39)));
                },
                getCurrentApy: async function (blockNumber, tvl) {
                  if (blockNumber === undefined && tvl === undefined) {
                    try {
                      return BigNumber.from(
                        (await axios.get(self.API_BASE_URL + "rgt/apy")).data
                      );
                    } catch (error) {
                      throw new Error("Error retrieving data from Rari API: " + error);
                    }
                  } else {
                    // Get APY from difference in distribution over last 270 blocks (estimating a 1 hour time difference)
                    var rgtDistributedPastHour = self.rgt.distributions
                      .getDistributedAtBlock(blockNumber)
                      .sub(
                        self.rgt.distributions.getDistributedAtBlock(blockNumber - 270)
                      );
                    var rgtDistributedPastHourPerUsd = rgtDistributedPastHour
                      .mul(constants.WeiPerEther)
                      .div(tvl);
                    var rgtDistributedPastHourPerUsdInUsd = rgtDistributedPastHourPerUsd
                      .mul(await self.rgt.getExchangeRate())
                      .div(constants.WeiPerEther);
                    return BigNumber.from(
                      Math.trunc(
                        ((1 + rgtDistributedPastHourPerUsdInUsd / 1e18) ** (24 * 365) -
                          1) *
                          1e18
                      )
                    );
                  }
                },
                getCurrentApr: async function (blockNumber: number, tvl: number) {
                  // Get APR from difference in distribution over last 270 blocks (estimating a 1 hour time difference)
                  const rgtDistributedPastHour = self.rgt.distributions
                    .getDistributedAtBlock(blockNumber)
                    .sub(
                      self.rgt.distributions.getDistributedAtBlock(blockNumber - 270)
                    );
                  const rgtDistributedPastHourPerUsd = rgtDistributedPastHour
                    .mul(constants.WeiPerEther)
                    .div(tvl);
                  const rgtDistributedPastHourPerUsdInUsd = rgtDistributedPastHourPerUsd
                    .mul(await self.rgt.getExchangeRate())
                    .div(constants.WeiPerEther);
                  return rgtDistributedPastHourPerUsdInUsd.mul(BigNumber.from(24 * 365));
                },
                getUnclaimed: async function (account: string): Promise<BigNumber> {
                  return await self.contracts.RariGovernanceTokenDistributor.getUnclaimedRgt(account)
                },
                claim: async function (amount, options) {
                  return await self.contracts.RariGovernanceTokenDistributor.claimRgt(amount)
                },
                claimAll: async function (options) {
                  return await self.contracts.RariGovernanceTokenDistributor.claimAllRgt()
                },
                getClaimFee: function (blockNumber) {
                  var initialClaimFee = utils.parseUnits("0.33");
                  if (blockNumber <= self.rgt.distributions.DISTRIBUTION_START_BLOCK)
                    return initialClaimFee;
                  var distributionEndBlock =
                    self.rgt.distributions.DISTRIBUTION_START_BLOCK +
                    self.rgt.distributions.DISTRIBUTION_PERIOD;
                  if (blockNumber >= distributionEndBlock) return constants.Zero;
                  return initialClaimFee
                    .mul(BigNumber.from(distributionEndBlock - blockNumber))
                    .div(BigNumber.from(distributionPeriod));
                },
                refreshDistributionSpeeds: async function (options) {
                  return await self.contracts.RariGovernanceTokenDistributor.refreshDistributionSpeeds()
                },
                refreshDistributionSpeedsByPool: async function (pool, options) {
                  return await self.contracts.RariGovernanceTokenDistributor.refreshDistributionSpeeds(pool)
                },
              },
            sushiSwapDistributions: {
                DISTRIBUTION_START_BLOCK: 11909000,
                DISTRIBUTION_PERIOD: 6500 * 365 * 3,
                //@ts-ignore
                DISTRIBUTION_PERIOD_END: this.DISTRIBUTION_PERIOD + this.DISTRIBUTION_START_BLOCK,
                FINAL_RGT_DISTRIBUTION: utils.parseUnits("568717819057309757517546")
                    .mul(BigNumber.from(80))
                    .div(BigNumber.from(100)),
                LP_TOKEN_CONTRACT,

                getDistributedAtBlock: function (blockNumber) {
                    const startBlock = self.rgt.sushiSwapDistributions.DISTRIBUTION_START_BLOCK;
                    if (blockNumber <= startBlock) return constants.Zero;

                    if ( blockNumber >= startBlock + self.rgt.sushiSwapDistributions.DISTRIBUTION_PERIOD ) return self.rgt.sushiSwapDistributions.FINAL_RGT_DISTRIBUTION;
                    
                    const blocks = blockNumber - startBlock;
                    return self.rgt.sushiSwapDistributions.FINAL_RGT_DISTRIBUTION.mul(BigNumber.from(blocks)).div(BigNumber.from(self.rgt.sushiSwapDistributions.DISTRIBUTION_PERIOD));
                },

                getCurrentApy: async function (blockNumber, totalStakedUsd) {
                    if (blockNumber === undefined && totalStakedUsd === undefined) {
                    try {
                        return BigNumber.from(
                        (await axios.get(self.API_BASE_URL + "rgt/sushiswap/apy")).data
                        );
                    } catch (error) {
                        throw new Error("Error retrieving data from Rari API: " + error);
                    }
                    } else {
                    // Predicted APY if we have't started the distribution period or we don't have enough data
                    if (
                        blockNumber - 270 <
                        self.rgt.sushiSwapDistributions.DISTRIBUTION_START_BLOCK
                    )
                        blockNumber =
                        self.rgt.sushiSwapDistributions.DISTRIBUTION_START_BLOCK + 270;
        
                    // Get APY from difference in distribution over last 270 blocks (estimating a 1 hour time difference)
                    const rgtDistributedPastHour = self.rgt.sushiSwapDistributions
                        .getDistributedAtBlock(blockNumber)
                        .sub(
                        self.rgt.sushiSwapDistributions.getDistributedAtBlock(
                            blockNumber - 270
                        )
                        );
                    const rgtDistributedPastHourPerUsd = rgtDistributedPastHour
                        .mul(constants.WeiPerEther)
                        .div(totalStakedUsd);
                    const rgtDistributedPastHourPerUsdInUsd = rgtDistributedPastHourPerUsd
                        .mul(await self.rgt.getExchangeRate())
                        .div(constants.WeiPerEther);
                    return BigNumber.from(
                        Math.trunc(
                        ((1 + rgtDistributedPastHourPerUsdInUsd / 1e18) ** (24 * 365) -
                            1) *
                            1e18
                        )
                    );
                    }
                },
                getCurrentApr: async function (blockNumber, totalStakedUsd) {
                    // Predicted APY if we have't started the distribution period or we don't have enough datac
                    if (
                    blockNumber - 270 <
                    self.rgt.sushiSwapDistributions.DISTRIBUTION_START_BLOCK
                    )
                    blockNumber =
                        self.rgt.sushiSwapDistributions.DISTRIBUTION_START_BLOCK + 270;
        
                    // Get APR from difference in distribution over last 270 blocks (estimating a 1 hour time difference)
                    const rgtDistributedPastHour = self.rgt.sushiSwapDistributions
                        .getDistributedAtBlock(blockNumber)
                        .sub(
                            self.rgt.sushiSwapDistributions.getDistributedAtBlock(
                            blockNumber - 270
                            )
                        );
                    const rgtDistributedPastHourPerUsd = rgtDistributedPastHour
                        .mul(constants.WeiPerEther)
                        .div(totalStakedUsd);
                    const rgtDistributedPastHourPerUsdInUsd = rgtDistributedPastHourPerUsd
                        .mul(await self.rgt.getExchangeRate())
                        .div(constants.WeiPerEther);
                    return rgtDistributedPastHourPerUsdInUsd.mul(BigNumber.from(24 * 365));
                },
                totalStaked: async function () {
                    return await self.contracts.RariGovernanceTokenUniswapDistributor.totalStaked()
                },
                getLpTokenData: async function () {
                    // TODO: RGT price getter function from Coingecko
                    return await self.cache.getOrUpdate("lpTokenData", async function () {
                    try {
                        return (
                        await axios.post(
                            "https://api.thegraph.com/subgraphs/name/zippoxer/sushiswap-subgraph-fork",
                            {
                            query: `{
                                ethRgtPair: pair(id: "0x18a797c7c70c1bf22fdee1c09062aba709cacf04") {
                                reserveUSD
                                reserve0
                                                    reserve1
                                totalSupply
                                }
                            }`,
                            }
                        )
                        ).data;
                    } catch (error) {
                        throw new Error(
                        "Error retrieving data from The Graph API: " + error
                        );
                    }
                    });
                },
                getLpTokenUsdPrice: async function () {
                    // TODO: RGT price getter function from Coingecko
                    const data = await self.rgt.sushiSwapDistributions.getLpTokenData();
                    const div = (data.data.ethRgtPair.reserveUSD / data.data.ethRgtPair.totalSupply).toString()
                    return utils.parseUnits(div)
                },
                getReservesPerLpToken: async function () {
                    // TODO: RGT price getter function from Coingecko
                    const data = await self.rgt.sushiSwapDistributions.getLpTokenData();
                    const rgtReserves = (data.data.ethRgtPair.reserve1 / data.data.ethRgtPair.totalSupply)
                    const ethReserves = (data.data.ethRgtPair.reserve0 / data.data.ethRgtPair.totalSupply)
                    return {
                        rgt: utils.parseUnits(rgtReserves.toString()),
                        eth: utils.parseUnits(ethReserves.toString()),
                    };
                },
                totalStakedUsd: async function () {
                    return (await self.rgt.sushiSwapDistributions.totalStaked())
                    .mul(await self.rgt.sushiSwapDistributions.getLpTokenUsdPrice())
                    .div(constants.WeiPerEther);
                },
                stakingBalanceOf: async function (account: string) {
                    return await self.contracts.RariGovernanceTokenUniswapDistributor.stakingBalances(account)
                },
                usdStakingBalanceOf: async function (account: string) {
                    return (
                    await self.rgt.sushiSwapDistributions.stakingBalanceOf(account)
                    )
                    .mul(await self.rgt.sushiSwapDistributions.getLpTokenUsdPrice())
                    .div(constants.WeiPerEther);
                },
                stakedReservesOf: async function (account: string) {
                    const stakingBalance = await self.rgt.sushiSwapDistributions.stakingBalanceOf(account);
                    const reservesPerLpToken = await self.rgt.sushiSwapDistributions.getReservesPerLpToken();
                    return {
                    rgt: reservesPerLpToken.rgt
                        .mul(stakingBalance)
                        .div(constants.WeiPerEther),
                    eth: reservesPerLpToken.eth
                        .mul(stakingBalance)
                        .div(constants.WeiPerEther),
                    };
                },
                deposit: async function (amount: BigNumber, sender: string) {
                    const slp = new Contract(LP_TOKEN_CONTRACT, ERC20ABI, self.provider.getSigner() );
                    const allowance = await slp.allowance(sender, self.contracts.RariGovernanceTokenUniswapDistributor.address)
                    if (amount.gt(allowance))
                        await slp.approve( self.contracts.RariGovernanceTokenUniswapDistributor.address, amount )
                    await self.contracts.RariGovernanceTokenUniswapDistributor.deposit(amount)
                },
                withdraw: async function (amount: BigNumber) {
                    await self.contracts.RariGovernanceTokenUniswapDistributor.withdraw(amount);
                },
                getUnclaimed: async function (account: string) {
                    return BigNumber.from(
                        await self.contracts.RariGovernanceTokenUniswapDistributor.getUnclaimedRgt(account)
                    );
                },
                claim: async function (amount: string) {
                    return await self.contracts.RariGovernanceTokenUniswapDistributor.claimRgt(amount)
                },
                claimAll: async function () {
                    return await self.contracts.RariGovernanceTokenUniswapDistributor.claimAllRgt()
                },
            },
            vesting: {
                PRIVATE_VESTING_START_TIMESTAMP: 1603202400,
                PRIVATE_VESTING_PERIOD: 2 * 365 * 86400,
                getUnclaimed: async function (account: string): Promise<BigNumber> {
                  return await self.contracts.RariGovernanceTokenVesting.getUnclaimedPrivateRgt(account)
                },
                claim: async function (amount, options) {
                  return await self.contracts.RariGovernanceTokenVesting.claimPrivateRgt(amount)
                },
                claimAll: async function (options) {
                  return await self.contracts.RariGovernanceTokenVesting.claimAllPrivateRgt()
                },
                getClaimFee: function (timestamp: number): BigNumber {
                  var initialClaimFee = constants.WeiPerEther;
                  if (timestamp <= self.rgt.vesting.PRIVATE_VESTING_START_TIMESTAMP)
                    return initialClaimFee;
                  var privateVestingEndTimestamp =
                    self.rgt.vesting.PRIVATE_VESTING_START_TIMESTAMP +
                    self.rgt.vesting.PRIVATE_VESTING_PERIOD;
                  if (timestamp >= privateVestingEndTimestamp)
                    return constants.Zero;
                  return initialClaimFee
                    .mul(BigNumber.from(privateVestingEndTimestamp - timestamp))
                    .div(BigNumber.from(self.rgt.vesting.PRIVATE_VESTING_PERIOD));
                },
            },
            balanceOf: async function (account: string) {
                return await self.contracts.RariGovernanceToken.balanceOf(account)
              },
            transfer: async function (recipient: string, amount: BigNumber) {
              return await self.contracts.RariGovernanceToken.transfer(recipient, amount)
            },
        }


    }
}
