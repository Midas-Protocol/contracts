import { deployments, ethers } from "hardhat";

import { Fuse } from "../../src";
import { ChainDeployment } from "../../src/Fuse/types";

let fuseSdk: Fuse;

export const getOrCreateFuse = async (): Promise<Fuse> => {
  console.log('fuseSdk: ', fuseSdk);
  if (!fuseSdk) {
    const { chainId } = await ethers.provider.getNetwork();
    let chainDeployment: ChainDeployment;
    if (chainId === 1337) {
      chainDeployment = {};
      const CErc20Delegate = await ethers.getContract("CErc20Delegate");
      const CErc20DelegateArtifact = await deployments.getArtifact("CErc20Delegate");
      chainDeployment.CErc20Delegate = { abi: CErc20DelegateArtifact.abi, address: CErc20Delegate.address };
      const CEtherDelegate = await ethers.getContract("CEtherDelegate");
      const CEtherDelegateArtifact = await deployments.getArtifact("CEtherDelegate");
      chainDeployment.CEtherDelegate = { abi: CEtherDelegateArtifact.abi, address: CEtherDelegate.address };
      const Comptroller = await ethers.getContract("Comptroller");
      const ComptrollerArtifact = await deployments.getArtifact("Comptroller.sol:Comptroller");
      chainDeployment.Comptroller = { abi: ComptrollerArtifact.abi, address: Comptroller.address };
      const FixedNativePriceOracle = await ethers.getContract("FixedNativePriceOracle");
      const FixedNativePriceOracleArtifact = await deployments.getArtifact("FixedNativePriceOracle");
      chainDeployment.FixedNativePriceOracle = { abi: FixedNativePriceOracleArtifact.abi, address: FixedNativePriceOracle.address };
      const FuseFeeDistributor = await ethers.getContract("FuseFeeDistributor");
      const FuseFeeDistributorArtifact = await deployments.getArtifact("FuseFeeDistributor");
      chainDeployment.FuseFeeDistributor = { abi: FuseFeeDistributorArtifact.abi, address: FuseFeeDistributor.address };
      const FusePoolDirectory = await ethers.getContract("FusePoolDirectory");
      const FusePoolDirectoryArtifact = await deployments.getArtifact("FusePoolDirectory");
      chainDeployment.FusePoolDirectory = { abi: FusePoolDirectoryArtifact.abi, address: FusePoolDirectory.address };
      const FusePoolLens = await ethers.getContract("FusePoolLens");
      const FusePoolLensArtifact = await deployments.getArtifact("FusePoolLens");
      chainDeployment.FusePoolLens = { abi: FusePoolLensArtifact.abi, address: FusePoolLens.address };
      const FusePoolLensSecondary = await ethers.getContract("FusePoolLensSecondary");
      const FusePoolLensSecondaryArtifact = await deployments.getArtifact("FusePoolLensSecondary");
      chainDeployment.FusePoolLensSecondary = { abi: FusePoolLensSecondaryArtifact.abi, address: FusePoolLensSecondary.address };
      const FuseSafeLiquidator = await ethers.getContract("FuseSafeLiquidator");
      const FuseSafeLiquidatorArtifact = await deployments.getArtifact("FuseSafeLiquidator");
      chainDeployment.FuseSafeLiquidator = { abi: FuseSafeLiquidatorArtifact.abi, address: FuseSafeLiquidator.address };
      const InitializableClones = await ethers.getContract("InitializableClones");
      const InitializableClonesArtifact = await deployments.getArtifact("InitializableClones");
      chainDeployment.InitializableClones = { abi: InitializableClonesArtifact.abi, address: InitializableClones.address };
      const JumpRateModel = await ethers.getContract("JumpRateModel");
      const JumpRateModelArtifact = await deployments.getArtifact("JumpRateModel");
      chainDeployment.JumpRateModel = { abi: JumpRateModelArtifact.abi, address: JumpRateModel.address };
      const MasterPriceOracle = await ethers.getContract("MasterPriceOracle");
      const MasterPriceOracleArtifact = await deployments.getArtifact("MasterPriceOracle");
      chainDeployment.MasterPriceOracle = { abi: MasterPriceOracleArtifact.abi, address: MasterPriceOracle.address };
      const RewardsDistributorDelegate = await ethers.getContract("RewardsDistributorDelegate");
      const RewardsDistributorDelegateArtifact = await deployments.getArtifact("RewardsDistributorDelegate");
      chainDeployment.RewardsDistributorDelegate = { abi: RewardsDistributorDelegateArtifact.abi, address: RewardsDistributorDelegate.address };
      const SimplePriceOracle = await ethers.getContract("SimplePriceOracle");
      const SimplePriceOracleArtifact = await deployments.getArtifact("SimplePriceOracle");
      chainDeployment.SimplePriceOracle = { abi: SimplePriceOracleArtifact.abi, address: SimplePriceOracle.address };
      const TOUCHToken = await ethers.getContract("TOUCHToken");
      const TOUCHTokenArtifact = await deployments.getArtifact("TOUCHToken");
      chainDeployment.TOUCHToken = { abi: TOUCHTokenArtifact.abi, address: TOUCHToken.address };
      const TRIBEToken = await ethers.getContract("TRIBEToken");
      const TRIBETokenArtifact = await deployments.getArtifact("TRIBEToken");
      chainDeployment.TRIBEToken = { abi: TRIBETokenArtifact.abi, address: TRIBEToken.address };
      const WhitePaperInterestRateModel = await ethers.getContract("WhitePaperInterestRateModel");
      const WhitePaperInterestRateModelArtifact = await deployments.getArtifact("WhitePaperInterestRateModel");
      chainDeployment.WhitePaperInterestRateModel = { abi: WhitePaperInterestRateModelArtifact.abi, address: WhitePaperInterestRateModel.address };
    }
    fuseSdk = new Fuse(ethers.provider, chainId, chainDeployment);
  }
  return fuseSdk;
};
