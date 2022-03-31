import { ethers } from "hardhat";

import { Fuse } from "../../src";
import { ChainDeployment } from "../../src/Fuse/types";

let fuseSdk: Fuse;

export const getOrCreateFuse = async (): Promise<Fuse> => {
  if (!fuseSdk) {
    const { chainId } = await ethers.provider.getNetwork();
    let chainDeployment: ChainDeployment;
    if (chainId === 1337) {
      chainDeployment = {};
      const CErc20Delegate = await ethers.getContract("CErc20Delegate");
      chainDeployment.CErc20Delegate = { abi: CErc20Delegate.abi, address: CErc20Delegate.address };
      const CEtherDelegate = await ethers.getContract("CEtherDelegate");
      chainDeployment.CEtherDelegate = { abi: CEtherDelegate.abi, address: CEtherDelegate.address };
      const Comptroller = await ethers.getContract("Comptroller");
      chainDeployment.Comptroller = { abi: Comptroller.abi, address: Comptroller.address };
      const DefaultProxyAdmin = await ethers.getContract("DefaultProxyAdmin");
      chainDeployment.DefaultProxyAdmin = { abi: DefaultProxyAdmin.abi, address: DefaultProxyAdmin.address };
      const FixedNativePriceOracle = await ethers.getContract("FixedNativePriceOracle");
      chainDeployment.FixedNativePriceOracle = { abi: FixedNativePriceOracle.abi, address: FixedNativePriceOracle.address };
      const FuseFeeDistributor = await ethers.getContract("FuseFeeDistributor");
      chainDeployment.FuseFeeDistributor = { abi: FuseFeeDistributor.abi, address: FuseFeeDistributor.address };
      const FusePoolDirectory = await ethers.getContract("FusePoolDirectory");
      chainDeployment.FusePoolDirectory = { abi: FusePoolDirectory.abi, address: FusePoolDirectory.address };
      const FusePoolLens = await ethers.getContract("FusePoolLens");
      chainDeployment.FusePoolLens = { abi: FusePoolLens.abi, address: FusePoolLens.address };
      const FusePoolLensSecondary = await ethers.getContract("FusePoolLensSecondary");
      chainDeployment.FusePoolLensSecondary = { abi: FusePoolLensSecondary.abi, address: FusePoolLensSecondary.address };
      const FuseSafeLiquidator = await ethers.getContract("FuseSafeLiquidator");
      chainDeployment.FuseSafeLiquidator = { abi: FuseSafeLiquidator.abi, address: FuseSafeLiquidator.address };
      const InitializableClones = await ethers.getContract("InitializableClones");
      chainDeployment.InitializableClones = { abi: InitializableClones.abi, address: InitializableClones.address };
      const JumpRateModel = await ethers.getContract("JumpRateModel");
      chainDeployment.JumpRateModel = { abi: JumpRateModel.abi, address: JumpRateModel.address };
      const MasterPriceOracle = await ethers.getContract("MasterPriceOracle");
      chainDeployment.MasterPriceOracle = { abi: MasterPriceOracle.abi, address: MasterPriceOracle.address };
      const RewardsDistributorDelegate = await ethers.getContract("RewardsDistributorDelegate");
      chainDeployment.RewardsDistributorDelegate = { abi: RewardsDistributorDelegate.abi, address: RewardsDistributorDelegate.address };
      const SimplePriceOracle = await ethers.getContract("SimplePriceOracle");
      chainDeployment.SimplePriceOracle = { abi: SimplePriceOracle.abi, address: SimplePriceOracle.address };
      const TOUCHToken = await ethers.getContract("TOUCHToken");
      chainDeployment.TOUCHToken = { abi: TOUCHToken.abi, address: TOUCHToken.address };
      const TRIBEToken = await ethers.getContract("TRIBEToken");
      chainDeployment.TRIBEToken = { abi: TRIBEToken.abi, address: TRIBEToken.address };
      const WhitePaperInterestRateModel = await ethers.getContract("WhitePaperInterestRateModel");
      chainDeployment.WhitePaperInterestRateModel = { abi: WhitePaperInterestRateModel.abi, address: WhitePaperInterestRateModel.address };
    }
    fuseSdk = new Fuse(ethers.provider, chainId, chainDeployment);
  }
  return fuseSdk;
};
