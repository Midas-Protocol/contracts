---
name: Initial Chain Deployment
about: Task for having a full SC deployment to a new chain
title: 'Initial Chain Deployment: <Chain Name>'
labels: ''
assignees: ''

---

## Chain Information

Link to Chain Developer docs: *XXX*

**Mainnet**
Chain Name:  *XXX* <br>
Chain ID:  *XXX* <br>
RPC URL:  *XXX* <br>
Native Token: *explorer url/XXX* <br>
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
*Please mark the tasks below, as appropriate.  Then link supporting Github items together in the Comments section either using # or the button in the screenshot below:* <br>
   ![Screenshot of Github Link Button](https://user-images.githubusercontent.com/103433798/169572470-b7e31053-afab-4225-9816-6403193b86b3.png)

- [ ] Please use the link below to add initial set of assets <br>
   - [Link to Custom Asset Template](https://github.com/Midas-Protocol/monorepo/issues/new?assignees=&labels=Custom+Asset+Support&template=custom-asset-support.md&title=Support+Asset+%24XXX)
- [ ] Create chain-specific deploy script inside `chainDeploy`
- [ ] Add the supported chain and its parameters to the [network configs](https://github.com/Midas-Protocol/contracts/blob/main/src/network.ts) of the SDK 
   - [ ] Blocks per year
   - [ ] Chain-specific addresses
   - [ ] Supported oracles
- [ ] Add network to hardhat config
- [ ] Run deploy script, export deployments and commit both `deployments.json` and deployments artifacts <br> <br>
**SDK**
- [ ] Add supported assets to chainConfig/supportedAssets
- [ ] Add chain ids to SupportedChains enum
- [ ] Redeploy SDK <br> <br>
**UI**
- [ ] Add Chain Mainnet and Testnet to `SwitchNetworkModal`
 - [ ] Add ChainMetadata for Main & Testnet
 - [ ] Make sure Main & Testnet are Listed in SupportedChains
 - [ ] Deactivate Mainnet via netlify.toml until specific release
