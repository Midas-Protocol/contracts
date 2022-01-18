# Contracts

1. Ensure `midas-sdk` is available locally, as per `packages.json` it should
be found in `../midas-sdk` w.r.t. this project.

2. Install deps, including `midas-sdk`
```shell
>>> npm install
>>> npm run build
>>> npm run export
```

3. Run local node:
```shell
>>> npx hardhat node --no-deploy --verbose
```

4. Run tests in another shell
```shell
>>> npx hardhat test --network localhost
```



