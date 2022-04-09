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

### Developing Against the SDK

To develop against the SDK, artifacts and deployment files must be generated first, as they are used by the SDK.
This is taken care by forge

```shell
>>> npm run build
```

Will generate all the required artifacts: `typechain` files, built contracts in `out` directory, and the newly built
SDK in `dist`. Another file that is extremely important for the correct behavior of the SDK is the
`deployments.json` file, which contains all the deployed contract addresses and ABIs for each of the 
chains we deploy to

Now, make the desired changes to the SDK. To test them, run the "integration" tests:

```shell
>>> npx hardhat test:hardhat
# with forking, see note below on forking
>>> npx hardhat test:bsc 
```

### Developing Against the contracts

Now, you make some changes to the contracts. Once statisfied:

```shell
>>> npm run build:forge
```

And then test the changes with forge-based tests:

```shell
>>> npm run test:forge
# tests with forking, see note below on forking
>>> npm run test:forge:bsc
```

At this point, you also want to run integration tests that leverage the SDK. For that, you need to 
regenerate the required artifacts:

```shell
# create freshly compiled artifacts
>>> npm run build
```

Redeploy the contracts locally

```shell
# deploy new contracts to localhost, and export them to the deployments.json file
>>> npx hardhat node --tags local
# in another console
>>> npm run export
# rebuild the SDK with the newly created artifacts
>>> npm run build
```

Once this is done, you can run the integration tests:


```shell
# Integration tests against local node
>>> npm run test:hardhat
```

```shell
# Integration tests against bsc fork node
>>> npm run test:bsc
```

**NOTE**: to run tests against a BSC forked node, set the correct env variables in `.env`:
```
FORK_URL_BSC=https://speedy-nodes-nyc.moralis.io/2d2926c3e761369208fba31f/bsc/mainnet/archive
# this is well before the deployment of our contracts, so you should start with a fresh set of contracts
FORK_BLOCK_NUMBER=14621736
FORK_CHAIN_ID=56
```

(if these env vars are set, the tests will always use them, so make sure to comment them out if you're intending
to run tests against a non-forked node)

## Running a node for FE development or integration testing

With the `.env` set up as above:

```shell
>>> npx hardhat node --tags fork
```
or alternatively, using the live currently deployed contracts (change the `FORK_BLOCK_NUMBER` to something recent)

```shell
# no deploy is needed because contracts at those addresses already exist
>>> npx hardhat node --tags prod --no-deploy
```

or alternatively, just run a local node without forking. Comment out all the `FORK_*` variables from the `.env` file
and:

```shell
>>> npx hardhat node --tags prod 
```

## Deploying to prod (BSC mainnet)

1. Set the correct mnemonic in the .env file

2. Run

```
hardhat --network bsc deploy --tags prod
```

### Current & Desired Workflow

Deployment flow of contracts:

1. Make desired changes, and push to branch, creating a PR against `main` branch
2. Ensure integration and forge tests pass for the local case (`npm run test:hardhat` and `npm run test:forge`)
3. Once the local tests pass, redeploy the contracts to all target chains
4. Export deployments files, and commit new deployment artifacts, and bump SDK version
6. Merge to main, which triggers new SDK release

This is OK, but it does not enforce the testing against the pre and post deploy BSC forked node. Our ideal scenario instead
looks like the following:

1. Make desired changes, and push to branch, creating a PR against `development` branch
2. Ensure integration and forge tests pass for the local case & for the pre-deploy forked node case
3. Once tests pass, redeploy the contracts to all target chains 
4. Export deployments files, and commit new deployment artifacts, and bump SDK version
5. Merge into `development` branch
6. Create PR from `development` into `main` 
7. Ensure tests against a **post-deploy** BSC fork works (both forge and hh-based tests). This will ensure that 
the newly deployed contracts are both integration and unit tested.
8. Update SDK, merge to `main`, which triggers new SDK release 