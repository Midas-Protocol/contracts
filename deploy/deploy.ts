import { constants } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Hardhat task defining the contract deployments for nxtp
 *
 * @param hre Hardhat environment to deploy to
 */
const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { bob, alice, deployer } = await getNamedAccounts();
  console.log("deployer: ", deployer);
  let dep = await deployments.deterministic("Comptroller", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });

  const comp = await dep.deploy();
  console.log("Comptroller: ", comp.address);

  dep = await deployments.deterministic("FusePoolDirectory", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fpd = await dep.deploy();
  console.log("FusePoolDirectory: ", fpd.address);
  const fusePoolDirectory = await ethers.getContract("FusePoolDirectory", deployer);
  let tx = await fusePoolDirectory.initialize(true, [deployer, alice, bob]);
  await tx.wait();

  dep = await deployments.deterministic("FuseSafeLiquidator", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fsl = await dep.deploy();
  console.log("FuseSafeLiquidator: ", fsl.address);

  dep = await deployments.deterministic("FuseFeeDistributor", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const ffd = await dep.deploy();
  console.log("FuseFeeDistributor: ", ffd.address);
  const fuseFeeDistributor = await ethers.getContract("FuseFeeDistributor", deployer);
  await fuseFeeDistributor.initialize(ethers.utils.parseEther("0.1"));
  await fuseFeeDistributor._setPoolLimits(
    ethers.utils.parseEther("1"),
    ethers.constants.MaxUint256,
    ethers.constants.MaxUint256
  );
  await fuseFeeDistributor._editComptrollerImplementationWhitelist([constants.AddressZero], [comp.address], [true]);

  dep = await deployments.deterministic("FusePoolLens", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fpl = await dep.deploy();
  console.log("FusePoolLens: ", fpl.address);
  const fusePoolLens = await ethers.getContract("FusePoolLens", deployer);
  await fusePoolLens.initialize(fusePoolDirectory.address);

  dep = await deployments.deterministic("FusePoolLensSecondary", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fpls = await dep.deploy();
  console.log("FusePoolLensSecondary: ", fpls.address);
  const fusePoolLensSecondary = await ethers.getContract("FusePoolLensSecondary", deployer);
  await fusePoolLensSecondary.initialize(fusePoolDirectory.address);

  dep = await deployments.deterministic("CErc20Delegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const erc20Del = await dep.deploy();
  console.log("CErc20Delegate: ", erc20Del.address);

  dep = await deployments.deterministic("CEtherDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const ethDel = await dep.deploy();
  console.log("CEtherDelegate: ", ethDel.address);

  await fuseFeeDistributor._editCEtherDelegateWhitelist([constants.AddressZero], [ethDel.address], [false], [true]);
  await fuseFeeDistributor._editCErc20DelegateWhitelist([constants.AddressZero], [erc20Del.address], [false], [true]);

  dep = await deployments.deterministic("MasterPriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const masterPO = await dep.deploy();
  console.log("MasterPriceOracle: ", masterPO.address);

  dep = await deployments.deterministic("MockPriceOracle", {
    from: bob,
    salt: ethers.utils.keccak256(deployer),
    args: [100],
    log: true,
  });
  const mockPO = await dep.deploy();
  console.log("MockPriceOracle: ", mockPO.address);

  const masterPriceOracle = await ethers.getContract("MasterPriceOracle", deployer);
  const mockPriceOracle = await ethers.getContract("MockPriceOracle", deployer);

  const underlyings = [
    "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9", // AAVE
    "0x8a12Be339B0cD1829b91Adc01977caa5E9ac121e", // CRV
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
  ];

  tx = await masterPriceOracle.initialize(
    underlyings,
    Array(4).fill(mockPriceOracle.address),
    mockPriceOracle.address,
    deployer,
    true
  );
  await tx.wait();

  // taken from IRM_COMP_Updateable
  //  https://etherscan.io/address/0xd956188795ca6F4A74092ddca33E0Ea4cA3a1395#code
  dep = await deployments.deterministic("JumpRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [
      "20000000000000000", // baseRatePerYear
      "180000000000000000", // multiplierPerYear
      "4000000000000000000", //jumpMultiplierPerYear
      "800000000000000000", // kink
    ],
    log: true,
  });

  const jrm = await dep.deploy();
  console.log("JumpRateModel: ", jrm.address);

  // taken from WhitePaperInterestRateModel used for cETH
  // https://etherscan.io/address/0x0c3f8df27e1a00b47653fde878d68d35f00714c0#code
  dep = await deployments.deterministic("WhitePaperInterestRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [
      "20000000000000000", // baseRatePerYear
      "100000000000000000", // multiplierPerYear
    ],
    log: true,
  });

  const wprm = await dep.deploy();
  console.log("WhitePaperInterestRateModel: ", wprm.address);

  //
  dep = await deployments.deterministic("RewardsDistributorDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [
      constants.AddressZero, // _rewardToken
    ],
    log: true,
  });

  const rewards = await dep.deploy();
  console.log("RewardsDistributorDelegate: ", rewards.address);
};

export default func;
