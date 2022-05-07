#!/bin/bash
set -x
POOL_NAME="Plugin Pool"

# get these from the console
export TOUCH=0xf9a089C918ad9c484201E7d328C0d29019997117
export MPO=0xb9e1c2B011f252B9931BBA7fcee418b95b6Bdc31
export STRATEGY=0x56385f347e18452C00801c9E5029E7658B017EB5
export IRM=0x5B3639BaDD3A08da48cBfb8F8451ff0035d9a4c8


export TRIBE=0x6F747d2A8900A04247F491d894D7765FdEc0D97a
#MPO=0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA
#IRM=0x2042FE5Fa3D58af48BB310374769857871B70428
#STRATEGY=0x22CaBeba065d1FF2FB5e53A97624121401BeaC57
FLYWHEEL=""

npx hardhat oracle:set-price --address $TOUCH --price "0.01" --network localhost

npx hardhat oracle:set-price --address $TRIBE --price "0.01" --network localhost

npx hardhat pool:create --name "$POOL_NAME" --creator deployer --price-oracle $MPO --close-factor 50 --liquidation-incentive 8 --enforce-whitelist false --network localhost


npx hardhat market:create --asset-config "$POOL_NAME,deployer,CErc20PluginDelegate,$TOUCH,$IRM,0.01,0.9,1,0,true,$STRATEGY,," --network localhost
npx hardhat market:create --asset-config "$POOL_NAME,deployer,CErc20Delegate,$TRIBE,$IRM,0.01,0.9,1,0,true,,," --network localhost


#npx hardhat oracle:set-price --address $TOUCH --price "0.01" --network localhost
#npx hardhat oracle:set-price --address $TRIBE --price "0.001" --network localhost

# no dynamic rewards

# dynamic rewards
#npx hardhat market:create --asset-config "$POOL_NAME,deployer,CErc20PluginRewardsDelegate,$TOUCH,$IRM,0.01,0.9,1,0,true,$STRATEGY,$FLYWHEEL,$REWARD" --network localhost


