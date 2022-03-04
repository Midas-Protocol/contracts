import { SALT } from "../../deploy/deploy";

export const deployUniswapOracle = async ({ ethers, getNamedAccounts, deployments, deployConfig }): Promise<void> => {
    const { deployer } = await getNamedAccounts();
    //// Uniswap Oracle
    let dep = await deployments.deterministic("UniswapTwapPriceOracleV2Root", {
        from: deployer,
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
        args: [deployConfig.wtoken],
        log: true,
    });
    const utpor = await dep.deploy();
    console.log("UniswapTwapPriceOracleV2Root: ", utpor.address);

    dep = await deployments.deterministic("UniswapTwapPriceOracleV2", {
        from: deployer,
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
        args: [],
        log: true,
    });
    const utpo = await dep.deploy();
    console.log("UniswapTwapPriceOracleV2: ", utpo.address);

    dep = await deployments.deterministic("UniswapTwapPriceOracleV2Factory", {
        from: deployer,
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(SALT)),
        args: [utpor.address, utpo.address, deployConfig.wtoken],
        log: true,
    });
    const utpof = await dep.deploy();
    console.log("UniswapTwapPriceOracleV2Factory: ", utpof.address);
};
