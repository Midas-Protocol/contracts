---
name: Custom Asset Support
about: Checklist for supporting custom assets
title: "[ASSET]"
labels: ''
assignees: ''

---

**Asset/Token Discovery**

*Checklist to determine if the asset in question meets certain requirements*

- [ ]  The asset must have a robust price feed, so that its price cannot be manipulated
- [ ]  The asset must be *liquidatable* i.e., it must be able to be converted to its underlying collateral in case its price drops below its collateral factor
- [ ]  Supported input & output tokens for the liquidation bot
    - [ ]  Native
    - [ ]  Wrapped Native
    - [ ]  Other?
- [ ]  Faucet (Acquire some native tokens for deployments)
    - [ ]  URL for Mainnet Faucet
    
    | URL |
    | --- |
    - [ ]  URL for Testnet
    
    | URL |
    | --- |
