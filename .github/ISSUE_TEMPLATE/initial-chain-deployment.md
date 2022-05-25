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
Chain Name:  XXX
Chain ID:  XXX
RPC URL:  XXX
Native Token: <explorer url/XXX>
Wrapped Native Token: <explorer url/XXX>

**Testnet**
Chain Name:  XXX
Chain ID:  XXX
RPC URL:  XXX
Native Token: <explorer url/XXX>
Wrapped Native Token: <explorer url/XXX>

**Ecosystem**
Uniswap-clone project name: XXX
Uniswap-clone docs: XXX

## Tasks

- [ ] Create chain-specific deploy script inside `chainDeploy`
- [ ] Add the supported chain and its parameters to the [network configs](https://github.com/Midas-Protocol/contracts/blob/main/src/network.ts) of the SDK 
   - [ ] Blocks per year
   - [ ] Chain-specific addresses
   - [ ] Supported oracles
- [ ] Add network to hardhat config
- [ ] Run deploy script, export deployments and commit both `deployments.json` and deployments artifacts
- [ ] Redeploy SDK
