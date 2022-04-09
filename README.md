# Contracts

Main repository for Midas Capital's contracts and SDK for interacting with those.

## Structure

```text
 ┌── README.md                        <- The top-level README
 ├── .github/workflows/TestSuite.yaml <- CICD pipeline definition
 ├── .vscode                          <- IDE configs
 │
 ├── out                              <- (forge-generated, git ignored)
 │    ├── *.sol/*.json                <- All the built contracts
 │    └──  ...                        
 │
 ├── typechain                        <- (typechain-generated, git ignored)
 │
 ├── dist                             <- (typechain-generated, git ignored)
 │
 ├── lib                              <- git submodules with forge-based dependencies
 │    ├── flywheel-v2                 <- Tribe flywheel contracts
 │    ├── fuse-flywheel               <- Fuse flywheel contracts
 │    ├── oz-contracts-upgreadable    <- OpenZeppelin deps
 │    └──  ...                        <- other deps
 │
 ├── contracts                        <- All of our contracts
 │    ├── compound                    <- Compound interfaces
 │    ├── external                    <- External contracts we require
 │    ├── oracles                     <- Oracle contracts
 │    ├── utils                       <- Utility contracts
 │    └──  ...                        <- Main Fuse contracts
 │
 ├── deploy                           <- main hardhat deployment scripts
 ├── chainDeploy                      <- hardhat chain-specific deployment scripts 
 ├── tasks                            <- hardhat scripts
 ├── src                              <- midas-sdk main folder
 ├── test                             <- chai-based tests (SDK integration tests)
 ├── deployments.json                 <- generated on "npx hardhat export"
 └── hardhat.config.ts                <- hardhat confing
```

## Dev Workflow

0. Install dependencies: npm & [foundry](https://github.com/gakonst/foundry) (forge + cast)

Forge dependencies

```text
>>> curl -L https://foundry.paradigm.xyz | bash 
>>> foundryup
# ensure forge and cast are available in your $PATH
# install submodule libraries via forge 
>>> forge install 
```

NPM dependencies

```text
>>> npm install
```

1. To develop against the SDK, artifacts and deployment files must be generated first, as they are used by the SDK.
This is taken case by forge

```shell
>>> npm run build
```
Will generate all the required artifacts: `typechain` files, built contracts in `out` directory, and the newly built
SDK in `dist`. Another file that is extremely important for the correct behavior of the SDK is the
`deployments.json` file, which contains all the deployed contract addresses and ABIs for each of the 
chains we deploy to

2. If you make change to the contracts, the built files, and thus their bytecode (and possibly ABIs) will
change. This requires you to re-build the SDK with newly generated artifacts. First, if you developed 
forge-based tests, ensure that they pass:

```shell
>>> npm run test:forge
# tests with forking, see note below on forking
>>> npm run test:forge:bsc
```

Then, to regenerate the required artifacts, do:

```shell
# create freshly compiled artifacts
>>> npm run build
```

```shell
# deploy new contracts to localhost, and export them to the deployments.json file
>>> npx hardhat node --tags local
# in another console
>>> npm run export
# rebuild the SDK with the newly created artifacts
>>> npm run build
```

3. Run the integration tests

```shell
>>> npx hardhat test:hardhat
# with forking, see note below on forking
>>> npx hardhat test:bsc 
```

**NOTE**: there are two ways of running the tests against BSC:

- Against freshly deployed contracts on the forked chain (by forking it at some point _before_ the currently
live deployed contracts have been deployed)

- Against the currently deployed contracts (by forking it at some point _after_ the currently
  live deployed contracts have been deployed)

This can be controlled by setting the correct env variables in `.env`:
```
FORK_URL_BSC=https://speedy-nodes-nyc.moralis.io/2d2926c3e761369208fba31f/bsc/mainnet/archive
# this is well before the deployment of our contracts, so you should start with a fresh set of contracts
FORK_BLOCK_NUMBER=14621736
FORK_CHAIN_ID=56
```
(if these env vars are set, the tests will always use them, so make sure to comment them out if you're intending
to run tests against a non-foked node)


## Running a node for FE development or integration testing

With the `.env` set up as above:

```shell
>>> npx hardhat node --tags fork
```

or alternatively, using the live currently deployed contracts (change the `FORK_BLOCK_NUMBER` to something recent)

```shell
>>> npx hardhat node --tags prod
```

5. To run the tests on a BSC mainnet fork, run

```
npm run test:forge:bsc
```

## Simulating a prod deploy

1. Add the chain-specific env vars in .env

2. Then run

```shell
>>> npx hardhat node --tags simulate
```

## Deploying to prod (BSC mainnet)

1. Set the correct mnemonic in the .env file

2. Run

```
hardhat --network bsc deploy --tags prod
```
