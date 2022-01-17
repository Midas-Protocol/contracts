import { constants } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments }): Promise<void> => {
  const { bob, alice, deployer } = await getNamedAccounts();

  let dep = await deployments.deterministic("FusePoolDirectory", {
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
  const comptroller = await ethers.getContract("Comptroller", deployer);
  await fuseFeeDistributor._editComptrollerImplementationWhitelist(
    [constants.AddressZero],
    [comptroller.address],
    [true]
  );

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

  const etherDelegate = await ethers.getContract("CEtherDelegate", deployer);
  const erc20Delegate = await ethers.getContract("CErc20Delegate", deployer);

  await fuseFeeDistributor._editCEtherDelegateWhitelist(
    [constants.AddressZero],
    [etherDelegate.address],
    [false],
    [true]
  );
  await fuseFeeDistributor._editCErc20DelegateWhitelist(
    [constants.AddressZero],
    [erc20Delegate.address],
    [false],
    [true]
  );

  dep = await deployments.deterministic("InitializableClones", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const ic = await dep.deploy();
  console.log("InitializableClones: ", ic.address);
};

func.tags = ["Fuse"];
func.dependencies = ["Compound", "IRM", "Oracles"];
export default func;
