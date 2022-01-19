# Contracts

Main repository for Midas Capital's contracts and SDK for interacting with those. 

## Structure
```text
 ┌── README.md                        <- The top-level README 
 ├── .github/workflows/TestSuite.yaml <- CICD pipeline definition
 ├── .vscode                          <- IDE configs
 │          
 │── artifacts                        <- (Auto-generated, git ignored)
 │       └── contracts                
 │                  ├── compound      <- Compiled contracts mirroring /contracts      
 │                  ├── external               
 │                  └──  ...      
 │
 ├── contracts                         <- All of our contracts
 │          ├── compound               <- Compound interfaces      
 │          ├── external               <- External contracts we require
 │          ├── oracles                <- Oracle contracts
 │          ├── utils                  <- Utility contracts 
 │          └──  ...                   <- Main Fuse contracts
 │
 ├── deploy                           <- hardhat deployment scripts
 ├── deployments                      <- hardhat-generated deployment files
 ├── scripts                          <- hardhat scripts
 ├── src                              <- midas-sdk main folder
 ├── deployments.json                 <- generated on "npx hardhat export"
 └── hardhat.config.ts                <- hardhat confing
```

## Dev Workflow

0. Install dependencies

```text
>>> npm install
```

2. To develop against the SDK, artifacts and deployment files must be generated first, as they are used by the SDK:

```text
>>> npx hardhat node 
# in another console
>>>> npm run export
```

3. Build the sdk

```text
>>> npm run build
```

4. Run tests

```shell
# must have the local hardhat node running in another shell
>>> npx hardhat test --network localhost
```
