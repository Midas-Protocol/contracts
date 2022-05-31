---
name: Initial Chain Deployment
about: Task for having a full SC deployment to a new chain
title: 'Initial Chain Deployment: <Chain Name>'
labels: ''
assignees: ''

---

## Chain Information

Developer docs: XXX

**Mainnet**
Chain Name:  *XXX* <br>
Chain ID:  *XXX* <br>
RPC URL:  *XXX* <br>
Native Token: *explorer url/XXX *<br>
Wrapped Native Token: *explorer url/XXX* <br>

**Testnet**
Chain Name: *XXX* <br>
Chain ID:  *XXX* <br>
RPC URL:  *XXX* <br>
Native Token: *explorer url/XXX* <br>
Wrapped Native Token: *explorer url/XXX* <br>

**Ecosystem**
Uniswap-clone project name: XXX <br>
Uniswap-clone docs: XXX <br>

## Tasks

- [ ] Please use the link below to add initial set of assets <br>
   - [Link to Custom Asset Template](https://github.com/Midas-Protocol/monorepo/issues/new?assignees=&labels=Custom+Asset+Support&template=custom-asset-support.md&title=Support+Asset+%24XXX)
- [ ] Create chain-specific deploy script inside `chainDeploy`
- [ ] Add the supported chain and its parameters to the [network configs](https://github.com/Midas-Protocol/contracts/blob/main/src/network.ts) of the SDK 
   - [ ] Blocks per year
   - [ ] Chain-specific addresses
   - [ ] Supported oracles
- [ ] Add network to hardhat config
- [ ] Run deploy script, export deployments and commit both `deployments.json` and deployments artifacts
- [ ] Redeploy SDK
