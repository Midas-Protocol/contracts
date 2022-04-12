---
name: Custom Asset Support
about: Add support for specific asset in a specific chain
title: Support Asset $XXX
labels: ''
assignees: ''

---

We'd like to support yet another custom asset

**Symbol**: ETH
**Block Explorer URL**:  https://etherscan.io/address/0x0000000000000000000000000000000000000000
**Chain**: Ethereum

- [ ] **ChainLink Supported**
- [ ] **Requires Custom Oracle** 
- [ ] **Requires Custom Liquidator**
- [ ] **ERC 4626 Support**
  - Link to ERC4626 ticket: N/A

### Tasks

- [ ] Implement custom oracle
- [ ] Implement custom liquidator
- [ ] Edit deployment script to set up and deploy oracle and liquidator
   - [ ] For ChainLink-supported oracles: add asset in the deploy script  e.g.: https://github.com/Midas-Protocol/contracts/blob/main/chainDeploy/mainnets/bsc.ts#L163
   - [ ] For Uniswap-supported assets, redeploy the fuse-twap-bot after adding editing the `supported_pairs` variable in the [webtwo-infra](https://github.com/Midas-Protocol/webtwo-infra#adding-a-twap-bot) repository
