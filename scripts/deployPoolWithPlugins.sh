#!/bin/bash
# set -x

POOL_NAME='Pool with Plugins'
ZERO=0x0000000000000000000000000000000000000000

NATIVE=$ZERO
TOUCH=0xa4498F7dBaBCF4248b0E9B8667aCb560252a8907
TRIBE=0x4557f20084DE100F2FCDC6f596e78BCAb6893562

MPO=0xF603C1212907aeec18034451CaD28CC2347b50d4
IRM=0x060C1e69Ee7aC35bFfa0D938FA085071F40bE45E

FLYWHEEL=""
REWARD=$TRIBE

echo "Deploying Strategy ..."
# TODO what was "--other-params again?" Might be wrong here

npx hardhat strategy:create --strategy-name AlpacaERC4626 --underlying $TOUCH --name Plugin-Alpaca-Token --symbol pATOKEN --creator deployer --other-params "0xd7D069493685A581d27824Fc46EdA46B7EfC0063" --network localhost
echo "------------------------------------------------------"
# TODO get strategy from cli call
STRATEGY=0x2ad88cffD3b57339E2727c60bFAC502FBf2173b8

echo "Deploying Pool: \"$POOL_NAME\" ... "
npx hardhat pool:create --name "\"$POOL_NAME\"" --creator deployer --price-oracle $MPO --close-factor 50 --liquidation-incentive 8 --enforce-whitelist false --network localhost
echo "------------------------------------------------------"
# # NATIVE vanilla CToken
# npx hardhat oracle:set-price --address 0x0000000000000000000000000000000000000000 --price "1" --network localhost
# npx hardhat market:create --asset-config Test,deployer,"CErc20Delegate",$NATIVE,0x060C1e69Ee7aC35bFfa0D938FA085071F40bE45E,0.01,0.9,1,0,true,"","","" --network localhost

# TRIBE with Plugin
echo "Deploying CErc20PluginDelegate ..."
npx hardhat oracle:set-price --address $TRIBE --price "0.001" --network localhost
npx hardhat market:create --asset-config "\"$POOL_NAME\"",deployer,"CErc20PluginDelegate",$TRIBE,$IRM,0.01,0.9,1,0,true,$STRATEGY,"","" --network localhost
echo "------------------------------------------------------"


# TOUCH with Plugin and Rewards
echo "Deploying CErc20PluginRewardsDelegate ... "
echo
npx hardhat oracle:set-price --address $TOUCH --price "0.01" --network localhost
npx hardhat market:create --asset-config "\"$POOL_NAME\"",deployer,"CErc20PluginRewardsDelegate",$TOUCH,$IRM,0.01,0.9,1,0,true,$STRATEGY,$FLYWHEEL,$REWARD --network localhost