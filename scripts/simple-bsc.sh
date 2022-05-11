#!/bin/bash
set -x
POOL_NAME="Plugin Pool"

# get these from the console
export MPO=0xb9e1c2B011f252B9931BBA7fcee418b95b6Bdc31
export STRATEGY=0x56385f347e18452C00801c9E5029E7658B017EB5
export IRM=0x5B3639BaDD3A08da48cBfb8F8451ff0035d9a4c8

export ETH=0x0000000000000000000000000000000000000000

export WBNB_DAI_LP=0xc7c3cCCE4FA25700fD5574DA7E200ae28BBd36A3
export WBNB_BUSD_LP=0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16

#MPO=0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA
#IRM=0x2042FE5Fa3D58af48BB310374769857871B70428
#STRATEGY=0x22CaBeba065d1FF2FB5e53A97624121401BeaC57
FLYWHEEL=""

npx hardhat pool:create --name "$POOL_NAME" --creator deployer --price-oracle $MPO --close-factor 50 --liquidation-incentive 8 --enforce-whitelist false --network localhost


npx hardhat market:create --asset-config "$POOL_NAME,deployer,CErc20PluginDelegate,$WBNB_BUSD_LP,$IRM,0.01,60,10,0,true,$STRATEGY,," --network localhost
npx hardhat market:create --asset-config "$POOL_NAME,deployer,CErc20PluginDelegate,$WBNB_DAI_LP,$IRM,0.01,60,10,0,true,$STRATEGY,," --network localhost
npx hardhat market:create --asset-config "$POOL_NAME,deployer,CErc20Delegate,$TRIBE,$IRM,0.01,70,10,0,true,,," --network localhost
npx hardhat market:create --asset-config "$POOL_NAME,deployer,,$ETH,$IRM,0.01,70,10,0,true,,," --network localhost

# get the pool address from the console
npx hardhat pools:deposit --amount 150 --symbol BTCB --pool-address $POOL_ADDRESS --enable-collateral true --account bob --network localhost
npx hardhat pools:deposit --amount 150 --symbol WBNB --pool-address $POOL_ADDRESS --enable-collateral true --account alice --network localhost
npx hardhat pools:borrow --amount 1 --symbol BTCB --pool-address $POOL_ADDRESS --account bob --network localhost

