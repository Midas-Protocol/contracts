// Ethers
import { BigNumber, constants, Contract, ContractFactory, providers, utils } from "ethers";
import { JsonRpcProvider, Web3Provider } from "@ethersproject/providers";
import { TransactionReceipt } from "@ethersproject/abstract-provider";
import axios from "axios";

// ABIs
import uniswapV3PoolAbiSlim from "./abi/UniswapV3Pool.slim.json";

// InterestRate Models
import JumpRateModel from "./irm/JumpRateModel";
import DAIInterestRateModelV2 from "./irm/DAIInterestRateModelV2";
import WhitePaperInterestRateModel from "./irm/WhitePaperInterestRateModel";

import Deployments from "../../deployments.json";
import ComptrollerArtifact from "../../artifacts/contracts/compound/Comptroller.sol/Comptroller.json";
import UnitrollerArtifact from "../../artifacts/contracts/compound/Unitroller.sol/Unitroller.json";
import CEtherDelegateArtifact from "../../artifacts/contracts/compound/CEtherDelegate.sol/CEtherDelegate.json";
import CEtherDelegatorArtifact from "../../artifacts/contracts/compound/CEtherDelegator.sol/CEtherDelegator.json";
import CErc20DelegateArtifact from "../../artifacts/contracts/compound/CErc20Delegate.sol/CErc20Delegate.json";
import CErc20DelegatorArtifact from "../../artifacts/contracts/compound/CErc20Delegator.sol/CErc20Delegator.json";
import CTokenInterfacesArtifact from "../../artifacts/contracts/compound/CTokenInterfaces.sol/CTokenInterface.json";
import EIP20InterfaceArtifact from "../../artifacts/contracts/compound/EIP20Interface.sol/EIP20Interface.json";
import RewardsDistributorDelegatorArtifact from "../../artifacts/contracts/compound/RewardsDistributorDelegator.sol/RewardsDistributorDelegator.json";
import PreferredPriceOracleArtifact from "../../artifacts/contracts/oracles/default/PreferredPriceOracle.sol/PreferredPriceOracle.json";

// Oracle Artifacts
import MasterPriceOracleArtifact from "../../artifacts/contracts/oracles/MasterPriceOracle.sol/MasterPriceOracle.json";
import SimplePriceOracleArtifact from "../../artifacts/contracts/oracles/1337/SimplePriceOracle.sol/SimplePriceOracle.json";
import ChainlinkPriceOracleV2Artifact from "../../artifacts/contracts/oracles/default/ChainlinkPriceOracleV2.sol/ChainlinkPriceOracleV2.json";

// IRM Artifacts
import JumpRateModelArtifact from "../../artifacts/contracts/compound/JumpRateModel.sol/JumpRateModel.json";
import DAIInterestRateModelV2Artifact from "../../artifacts/contracts/compound/DAIInterestRateModelV2.sol/DAIInterestRateModelV2.json";
import WhitePaperInterestRateModelArtifact from "../../artifacts/contracts/compound/WhitePaperInterestRateModel.sol/WhitePaperInterestRateModel.json";

// Types
import {
  Artifact,
  Artifacts,
  cERC20Conf,
  ChainDeployment,
  FusePoolData,
  InterestRateModel,
  InterestRateModelConf,
  InterestRateModelParams,
  OracleConf,
  USDPricedFuseAsset,
} from "./types";
import { COMPTROLLER_ERROR_CODES, CTOKEN_ERROR_CODES, JUMP_RATE_MODEL_CONF, SIMPLE_DEPLOY_ORACLES } from "./config";
import { chainOracles, chainSpecificAddresses, irmConfig, oracleConfig, SupportedChains } from "../network";
import { filterOnlyObjectProperties, filterPoolName } from "./utils";

type OracleConfig = {
  [contractName: string]: {
    artifact: Artifact;
    address: string;
  };
};

type IrmConfig = OracleConfig;

type ChainSpecificAddresses = {
  [tokenName: string]: string;
};

export default class Fuse {
  public provider: JsonRpcProvider | Web3Provider;
  public contracts: {
    FusePoolDirectory: Contract;
    FusePoolLens: Contract;
    FusePoolLensSecondary: Contract;
    FuseSafeLiquidator: Contract;
    FuseFeeDistributor: Contract;
  };
  static SIMPLE_DEPLOY_ORACLES = SIMPLE_DEPLOY_ORACLES;
  static COMPTROLLER_ERROR_CODES = COMPTROLLER_ERROR_CODES;
  static CTOKEN_ERROR_CODES = CTOKEN_ERROR_CODES;
  static JumpRateModelConf: InterestRateModelConf = JUMP_RATE_MODEL_CONF;

  public availableOracles: Array<string>;
  public chainId: SupportedChains;
  public chainDeployment: ChainDeployment;
  public oracles: OracleConfig;
  private readonly irms: IrmConfig;
  public chainSpecificAddresses: ChainSpecificAddresses;
  public artifacts: Artifacts;

  constructor(web3Provider: JsonRpcProvider | Web3Provider, chainId: SupportedChains) {
    this.provider = web3Provider;
    this.chainId = chainId;
    this.availableOracles = chainOracles[chainId];
    this.chainDeployment =
      Deployments[chainId.toString()] &&
      Deployments[chainId.toString()][Object.keys(Deployments[chainId.toString()])[0]]?.contracts;
    if (!this.chainDeployment) {
      throw new Error(`Chain deployment not found for chainId ${chainId}`);
    }

    this.chainSpecificAddresses = chainSpecificAddresses[chainId];

    this.contracts = {
      FusePoolDirectory: new Contract(
        this.chainDeployment.FusePoolDirectory.address,
        this.chainDeployment.FusePoolDirectory.abi,
        this.provider
      ),
      FusePoolLens: new Contract(
        this.chainDeployment.FusePoolLens.address,
        this.chainDeployment.FusePoolLens.abi,
        this.provider
      ),
      FusePoolLensSecondary: new Contract(
        this.chainDeployment.FusePoolLensSecondary.address,
        this.chainDeployment.FusePoolLensSecondary.abi,
        this.provider
      ),
      FuseSafeLiquidator: new Contract(
        this.chainDeployment.FuseSafeLiquidator.address,
        this.chainDeployment.FuseSafeLiquidator.abi,
        this.provider
      ),
      FuseFeeDistributor: new Contract(
        this.chainDeployment.FuseFeeDistributor.address,
        this.chainDeployment.FuseFeeDistributor.abi,
        this.provider
      ),
    };
    this.artifacts = {
      Comptroller: ComptrollerArtifact,
      Unitroller: UnitrollerArtifact,
      CEtherDelegate: CEtherDelegateArtifact,
      CEtherDelegator: CEtherDelegatorArtifact,
      CErc20Delegate: CErc20DelegateArtifact,
      CErc20Delegator: CErc20DelegatorArtifact,
      CTokenInterfaces: CTokenInterfacesArtifact,
      EIP20Interface: EIP20InterfaceArtifact,
      RewardsDistributorDelegator: RewardsDistributorDelegatorArtifact,
      PreferredPriceOracle: PreferredPriceOracleArtifact,
      JumpRateModel: JumpRateModelArtifact,
      DAIInterestRateModelV2: DAIInterestRateModelV2Artifact,
      WhitePaperInterestRateModel: WhitePaperInterestRateModelArtifact,
      ChainlinkPriceOracleV2: ChainlinkPriceOracleV2Artifact,
      MasterPriceOracle: MasterPriceOracleArtifact,
      SimplePriceOracle: SimplePriceOracleArtifact,
    };
    this.irms = irmConfig(this.chainDeployment, this.artifacts);
    this.oracles = oracleConfig(this.chainDeployment, this.artifacts, this.availableOracles);
  }

  // TODO: probably should determine this by chain
  async getUsdPriceBN(coingeckoId: string = 'ethereum', asBigNumber: boolean = false): Promise<number | BigNumber> {
    // Returns a USD price. Which means its a floating point of at least 2 decimal numbers.
    const UsdPrice = (await axios.get(`https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=${coingeckoId}`))
      .data[coingeckoId].usd;

    if (asBigNumber) {
      return utils.parseUnits(UsdPrice.toString(), 18);
    }

    return UsdPrice;
  }

  async deployPool(
    poolName: string,
    enforceWhitelist: boolean,
    closeFactor: BigNumber,
    liquidationIncentive: BigNumber,
    priceOracle: string, // Contract address
    priceOracleConf: OracleConf,
    options: any, // We might need to add sender as argument. Getting address from options will colide with the override arguments in ethers contract method calls. It doesnt take address.
    whitelist: string[] // An array of whitelisted addresses
  ): Promise<[string, string, string]> {
    // 2. Deploy Comptroller implementation if necessary
    let implementationAddress = this.chainDeployment.Comptroller.address;

    if (!implementationAddress) {
      const comptrollerContract = new ContractFactory(
        this.artifacts.Comptroller.abi,
        this.artifacts.Comptroller.bytecode,
        this.provider.getSigner(options.from)
      );
      const deployedComptroller = await comptrollerContract.deploy();
      implementationAddress = deployedComptroller.address;
    }

    //3. Register new pool with FusePoolDirectory
    let receipt: providers.TransactionReceipt;
    try {
      const contract = this.contracts.FusePoolDirectory.connect(this.provider.getSigner(options.from));
      const tx = await contract.deployPool(
        poolName,
        implementationAddress,
        enforceWhitelist,
        closeFactor,
        liquidationIncentive,
        priceOracle
      );
      receipt = await tx.wait();
      console.log(`Deployment of pool ${poolName} succeeded!`);
    } catch (error: any) {
      throw Error("Deployment and registration of new Fuse pool failed: " + (error.message ? error.message : error));
    }
    //4. Compute Unitroller address
    const saltsHash = utils.solidityKeccak256(
      ["address", "string", "uint"],
      [options.from, poolName, receipt.blockNumber]
    );
    const byteCodeHash = utils.keccak256(this.artifacts.Unitroller.bytecode);

    const poolAddress = utils.getCreate2Address(
      this.chainDeployment.FusePoolDirectory.address,
      saltsHash,
      byteCodeHash
    );

    const unitroller = new Contract(poolAddress, this.artifacts.Unitroller.abi, this.provider.getSigner(options.from));

    // Accept admin status via Unitroller
    try {
      const tx = await unitroller._acceptAdmin();
      const receipt = await tx.wait();
      console.log(receipt.status, "Accepted admin status for admin: ");
    } catch (error: any) {
      throw Error("Accepting admin status failed: " + (error.message ? error.message : error));
    }

    // Whitelist
    console.log("enforceWhitelist: ", enforceWhitelist);
    if (enforceWhitelist) {
      let comptroller = new Contract(
        poolAddress,
        this.artifacts.Comptroller.abi,
        this.provider.getSigner(options.from)
      );

      // Already enforced so now we just need to add the addresses
      console.log("whitelist: ", whitelist);
      await comptroller._setWhitelistStatuses(whitelist, Array(whitelist.length).fill(true));
    }

    return [poolAddress, implementationAddress, priceOracle];
  }

  private async getOracleContractFactory(contractName: string, signer?: string): Promise<ContractFactory> {
    let oracleArtifact: { abi: any; bytecode: any };
    switch (contractName) {
      case "ChainlinkPriceOracleV2": {
        oracleArtifact = this.oracles.ChainlinkPriceOracleV2.artifact;
        break;
      }
      default:
        throw Error(`Oracle contract ${contractName} not found`);
    }
    return new ContractFactory(oracleArtifact.abi, oracleArtifact.bytecode, this.provider.getSigner(signer));
  }

  async deployAsset(
    irmConf: InterestRateModelConf,
    cTokenConf: cERC20Conf,
    options: any
  ): Promise<[string, string, string, TransactionReceipt]> {
    let assetAddress: string;
    let implementationAddress: string;
    let receipt: providers.TransactionReceipt;
    // Deploy new interest rate model via SDK if requested
    if (
      ["WhitePaperInterestRateModel", "JumpRateModel", "DAIInterestRateModelV2"].indexOf(irmConf.interestRateModel!) >=
      0
    ) {
      try {
        irmConf.interestRateModel = await this.deployInterestRateModel(
          options,
          irmConf.interestRateModel,
          irmConf.interestRateModelParams
        ); // TODO: anchorMantissa
      } catch (error: any) {
        throw Error("Deployment of interest rate model failed: " + (error.message ? error.message : error));
      }
    }
    // Deploy new asset to existing pool via SDK
    try {
      [assetAddress, implementationAddress, receipt] = await this.deployCToken(cTokenConf, options);
    } catch (error: any) {
      throw Error("Deployment of asset to Fuse pool failed: " + (error.message ? error.message : error));
    }
    return [assetAddress, implementationAddress, irmConf.interestRateModel!, receipt];
  }

  async deployInterestRateModel(options: any, model?: string, conf?: InterestRateModelParams): Promise<string> {
    // Default model = JumpRateModel
    if (!model) {
      model = "JumpRateModel";
    }

    // Get deployArgs
    let deployArgs: any[] = [];
    let modelArtifact: { abi: any; bytecode: any };

    switch (model) {
      case "JumpRateModel":
        if (!conf)
          conf = {
            baseRatePerYear: "20000000000000000",
            multiplierPerYear: "200000000000000000",
            jumpMultiplierPerYear: "2000000000000000000",
            kink: "900000000000000000",
          };
        deployArgs = [conf.baseRatePerYear, conf.multiplierPerYear, conf.jumpMultiplierPerYear, conf.kink];
        modelArtifact = this.artifacts.JumpRateModel;
        break;
      case "DAIInterestRateModelV2":
        if (!conf)
          conf = {
            jumpMultiplierPerYear: "2000000000000000000",
            kink: "900000000000000000",
          };
        deployArgs = [
          conf.jumpMultiplierPerYear,
          conf.kink,
          this.chainSpecificAddresses.DAI_POT,
          this.chainSpecificAddresses.DAI_JUG,
        ];
        modelArtifact = this.artifacts.DAIInterestRateModelV2;
        break;
      case "WhitePaperInterestRateModel":
        if (!conf)
          conf = {
            baseRatePerYear: "20000000000000000",
            multiplierPerYear: "200000000000000000",
          };
        deployArgs = [conf.baseRatePerYear, conf.multiplierPerYear];
        modelArtifact = this.artifacts.WhitePaperInterestRateModel;
        break;
      default:
        throw "IRM model specified is invalid";
    }

    // Deploy InterestRateModel
    const interestRateModelContract = new ContractFactory(
      modelArtifact.abi,
      modelArtifact.bytecode,
      this.provider.getSigner(options.from)
    );

    const deployedInterestRateModel = await interestRateModelContract.deploy(...deployArgs);
    return deployedInterestRateModel.address;
  }

  async deployCToken(conf: cERC20Conf, options: any): Promise<[string, string, TransactionReceipt]> {
    // BigNumbers
    // 10% -> 0.1 * 1e18
    const reserveFactorBN = utils.parseEther((conf.reserveFactor / 100).toString());
    // 5% -> 0.05 * 1e18
    const adminFeeBN = utils.parseEther((conf.adminFee / 100).toString());
    // 50% -> 0.5 * 1e18
    // TODO: find out if this is a number or string. If its a number, parseEther will not work. Also parse Units works if number is between 0 - 0.9
    const collateralFactorBN = utils.parseEther((conf.collateralFactor / 100).toString());
    // Check collateral factor
    if (!collateralFactorBN.gte(constants.Zero) || collateralFactorBN.gt(utils.parseEther("0.9")))
      throw Error("Collateral factor must range from 0 to 0.9.");

    // Check reserve factor + admin fee + Fuse fee
    if (!reserveFactorBN.gte(constants.Zero)) throw Error("Reserve factor cannot be negative.");
    if (!adminFeeBN.gte(constants.Zero)) throw Error("Admin fee cannot be negative.");

    // If reserveFactor or adminFee is greater than zero, we get fuse fee.
    // Sum of reserveFactor and adminFee should not be greater than fuse fee. ? i think
    if (reserveFactorBN.gt(constants.Zero) || adminFeeBN.gt(constants.Zero)) {
      const fuseFee = await this.contracts.FuseFeeDistributor.interestFeeRate();
      if (reserveFactorBN.add(adminFeeBN).add(BigNumber.from(fuseFee)).gt(constants.WeiPerEther))
        throw Error(
          "Sum of reserve factor and admin fee should range from 0 to " + (1 - parseInt(fuseFee) / 1e18) + "."
        );
    }

    return conf.underlying !== undefined &&
      conf.underlying !== null &&
      conf.underlying.length > 0 &&
      !BigNumber.from(conf.underlying).isZero()
      ? await this.deployCErc20(
          conf,
          options,
          this.chainDeployment.CErc20Delegate.address ? this.chainDeployment.CErc20Delegate.address : null
        )
      : await this.deployCEther(
          conf,
          options,
          this.chainDeployment.CEtherDelegate.address ? this.chainDeployment.CEtherDelegate.address : null
        );
  }

  async deployCEther(
    conf: cERC20Conf,
    options: any,
    implementationAddress: string | null
  ): Promise<[string, string, TransactionReceipt]> {
    const reserveFactorBN = utils.parseUnits((conf.reserveFactor / 100).toString());
    const adminFeeBN = utils.parseUnits((conf.adminFee / 100).toString());
    const collateralFactorBN = utils.parseUnits((conf.collateralFactor / 100).toString());

    // Deploy CEtherDelegate implementation contract if necessary
    if (!implementationAddress) {
      const cEtherDelegateFactory = new ContractFactory(
        this.artifacts.CEtherDelegate.abi,
        this.artifacts.CEtherDelegate.bytecode,
        this.provider.getSigner(options.from)
      );

      const cEtherDelegateDeployed = await cEtherDelegateFactory.deploy();
      implementationAddress = cEtherDelegateDeployed.address;
    }

    let deployArgs = [
      conf.comptroller,
      conf.interestRateModel,
      conf.name,
      conf.symbol,
      implementationAddress,
      "0x00",
      reserveFactorBN,
      adminFeeBN,
    ];
    const abiCoder = new utils.AbiCoder();
    const constructorData = abiCoder.encode(
      ["address", "address", "string", "string", "address", "bytes", "uint256", "uint256"],
      deployArgs
    );
    const comptroller = new Contract(
      conf.comptroller,
      this.artifacts.Comptroller.abi,
      this.provider.getSigner(options.from)
    );

    const comptrollerWithSigner = comptroller.connect(this.provider.getSigner(options.from));
    const errorCode = await comptroller.callStatic._deployMarket(
      "0x0000000000000000000000000000000000000000",
      constructorData,
      collateralFactorBN
    );
    if (errorCode.toNumber() !== 0) {
      throw `Failed to _deployMarket: ${Fuse.COMPTROLLER_ERROR_CODES[errorCode.toNumber()]}`;
    }

    const tx = await comptrollerWithSigner._deployMarket(
      "0x0000000000000000000000000000000000000000",
      constructorData,
      collateralFactorBN
    );

    const receipt: TransactionReceipt = await tx.wait();

    if (receipt.status != constants.One.toNumber()) {
      throw "Failed to deploy market ";
    }

    const saltsHash = utils.solidityKeccak256(
      ["address", "address", "uint"],
      [conf.comptroller, "0x0000000000000000000000000000000000000000", receipt.blockNumber]
    );

    const byteCodeHash = utils.keccak256(this.artifacts.CEtherDelegator.bytecode + constructorData.substring(2));

    const cEtherDelegatorAddress = utils.getCreate2Address(
      this.chainDeployment.FuseFeeDistributor.address,
      saltsHash,
      byteCodeHash
    );

    // Return cToken proxy and implementation contract addresses
    return [cEtherDelegatorAddress, implementationAddress, receipt];
  }

  async deployCErc20(
    conf: cERC20Conf,
    options: any,
    implementationAddress: string | null // cERC20Delegate implementation
  ): Promise<[string, string, TransactionReceipt]> {
    const reserveFactorBN = utils.parseUnits((conf.reserveFactor / 100).toString());
    const adminFeeBN = utils.parseUnits((conf.adminFee / 100).toString());
    const collateralFactorBN = utils.parseUnits((conf.collateralFactor / 100).toString());

    // Get Comptroller
    const comptroller = new Contract(
      conf.comptroller,
      this.artifacts.Comptroller.abi,
      this.provider.getSigner(options.from)
    );

    // Check for price feed assuming !bypassPriceFeedCheck
    if (!conf.bypassPriceFeedCheck) await this.checkForCErc20PriceFeed(comptroller, conf);

    // Deploy CErc20Delegate implementation contract if necessary
    if (!implementationAddress) {
      if (!conf.delegateContractName) conf.delegateContractName = "CErc20Delegate";
      let delegateContractArtifact: { abi: any; bytecode: any };
      if (conf.delegateContractName === "CErc20Delegate") {
        delegateContractArtifact = this.artifacts.CErc20Delegate;
      } else {
        delegateContractArtifact = this.artifacts.CEtherDelegate;
      }
      const cErc20Delegate = new ContractFactory(
        delegateContractArtifact.abi,
        delegateContractArtifact.bytecode,
        this.provider.getSigner(options.from)
      );
      const cErc20DelegateDeployed = await cErc20Delegate.deploy();
      implementationAddress = cErc20DelegateDeployed.address;
    }

    // Deploy CEtherDelegator proxy contract
    let deployArgs = [
      conf.underlying,
      conf.comptroller,
      conf.interestRateModel,
      conf.name,
      conf.symbol,
      implementationAddress,
      "0x00",
      reserveFactorBN,
      adminFeeBN,
    ];

    const abiCoder = new utils.AbiCoder();
    const constructorData = abiCoder.encode(
      ["address", "address", "address", "string", "string", "address", "bytes", "uint256", "uint256"],
      deployArgs
    );

    const errorCode = await comptroller.callStatic._deployMarket(false, constructorData, collateralFactorBN);
    if (errorCode.toNumber() !== 0) {
      throw `Failed to _deployMarket: ${Fuse.COMPTROLLER_ERROR_CODES[errorCode.toNumber()]}`;
    }

    const tx = await comptroller._deployMarket(false, constructorData, collateralFactorBN);
    const receipt: TransactionReceipt = await tx.wait();

    if (receipt.status != constants.One.toNumber())
      // throw "Failed to deploy market with error code: " + Fuse.COMPTROLLER_ERROR_CODES[errorCode];
      throw "Failed to deploy market ";

    const saltsHash = utils.solidityKeccak256(
      ["address", "address", "uint"],
      [conf.comptroller, conf.underlying, receipt.blockNumber]
    );
    const byteCodeHash = utils.keccak256(this.artifacts.CErc20Delegator.bytecode + constructorData.substring(2));

    const cErc20DelegatorAddress = utils.getCreate2Address(
      this.chainDeployment.FuseFeeDistributor.address,
      saltsHash,
      byteCodeHash
    );

    // Return cToken proxy and implementation contract addresses
    return [cErc20DelegatorAddress, implementationAddress, receipt];
  }

  async identifyPriceOracle(priceOracleAddress: string) {
    // Get PriceOracle type from runtime bytecode hash
    const runtimeBytecodeHash = utils.keccak256(await this.provider.getCode(priceOracleAddress));

    for (const [name, oracle] of Object.entries(this.oracles)) {
      const value = utils.keccak256(oracle.artifact.bytecode);
      if (runtimeBytecodeHash == value) return name;
    }
    return null;
  }

  async identifyInterestRateModel(interestRateModelAddress: string): Promise<InterestRateModel | null> {
    // Get interest rate model type from runtime bytecode hash and init class
    const interestRateModels: { [key: string]: any } = {
      JumpRateModel: JumpRateModel,
      DAIInterestRateModelV2: DAIInterestRateModelV2,
      WhitePaperInterestRateModel: WhitePaperInterestRateModel,
    };
    const runtimeBytecodeHash = utils.keccak256(await this.provider.getCode(interestRateModelAddress));

    let irmModel = null;

    for (const irm of Object.values(interestRateModels)) {
      if (runtimeBytecodeHash === irm.RUNTIME_BYTECODE_HASH) {
        irmModel = new irm();
        break;
      }
    }
    return irmModel;
  }

  async getInterestRateModel(assetAddress: string): Promise<any | undefined | null> {
    // Get interest rate model address from asset address
    const assetContract = new Contract(assetAddress, this.artifacts.CTokenInterfaces.abi, this.provider);
    const interestRateModelAddress: string = await assetContract.callStatic.interestRateModel();

    const interestRateModel = await this.identifyInterestRateModel(interestRateModelAddress);
    if (interestRateModel === null) {
      return null;
    }
    await interestRateModel.init(interestRateModelAddress, assetAddress, this.provider);
    return interestRateModel;
  }

  async checkForCErc20PriceFeed(
    comptroller: Contract,
    conf: {
      underlying: string; // Address of the underlying ERC20 Token
    },
    options: any = {}
  ) {
    // Get price feed
    // 1. Get priceOracle's address used by the comprtroller. PriceOracle can have multiple implementations so:
    // 1.1 We try to figure out which implementation it is, by (practically) bruteforcing it.
    //1.1.2 We first assume its a ChainlinkPriceOracleV2.
    //1.1.3 We then try with PrefferedOracle's primary oracle i.e ChainlinkPriceOracleV2
    //1.1.4 We try with UniswapAnchoredView
    //1.1.5 We try with UniswapView
    //1.1.6 We try with PrefferedOracle's secondary oracle i.e UniswapAnchoredView or UniswapView
    //1.1.6

    // 2. Check

    // Get address of the priceOracle used by the comptroller
    const priceOracle: string = await comptroller.callStatic.oracle();

    // Check for a ChainlinkPriceOracleV2 with a feed for the ERC20 Token
    let chainlinkPriceOracle: Contract;
    let chainlinkPriceFeed: boolean | undefined = undefined; // will be true if chainlink has a price feed for underlying Erc20 token

    chainlinkPriceOracle = new Contract(priceOracle, this.oracles.ChainlinkPriceOracleV2.artifact.abi, this.provider);

    // If underlying Erc20 is WETH use chainlinkPriceFeed, otherwise check if Chainlink supports it.
    if (conf.underlying.toLowerCase() === this.chainSpecificAddresses.W_TOKEN.toLowerCase()) {
      chainlinkPriceFeed = true;
    } else {
      try {
        chainlinkPriceFeed = await chainlinkPriceOracle.hasPriceFeed(conf.underlying);
      } catch {}
    }

    if (chainlinkPriceFeed === undefined || !chainlinkPriceFeed) {
      const preferredPriceOracle = new Contract(priceOracle, this.artifacts.PreferredPriceOracle.abi, this.provider);

      try {
        // Get the underlying ChainlinkOracle address of the PreferredPriceOracle
        const chainlinkPriceOracleAddress = await preferredPriceOracle.chainlinkOracle();

        // Initiate ChainlinkOracle
        chainlinkPriceOracle = new Contract(
          chainlinkPriceOracleAddress,
          this.oracles.ChainlinkPriceOracleV2.artifact.abi,
          this.provider
        );

        // Check if chainlink has an available price feed for the Erc20Token
        chainlinkPriceFeed = await chainlinkPriceOracle.hasPriceFeed(conf.underlying);
      } catch {}
    }

    // TODO: find this contract and fix this!
    if (chainlinkPriceFeed === undefined || !chainlinkPriceFeed) {
      throw new Error("FIX THE UNISWAP ORACLE ANCHORED VIEW");
    }
    /*
    if (chainlinkPriceFeed === undefined || !chainlinkPriceFeed) {
      // Check if we can get a UniswapAnchoredView
      var isUniswapAnchoredView = false;

      let uniswapOrUniswapAnchoredViewContract: Contract;
      try {
        uniswapOrUniswapAnchoredViewContract = new Contract(
          priceOracle,
          JSON.parse(this.openOracleContracts["contracts/Uniswap/UniswapAnchoredView.sol:UniswapAnchoredView"].abi),
          this.provider
        );
        await uniswapOrUniswapAnchoredViewContract.IS_UNISWAP_ANCHORED_VIEW();
        isUniswapAnchoredView = true;
      } catch {
        try {
          uniswapOrUniswapAnchoredViewContract = new Contract(
            priceOracle,
            JSON.parse(this.openOracleContracts["contracts/Uniswap/UniswapView.sol:UniswapView"].abi),
            this.provider
          );
          await uniswapOrUniswapAnchoredViewContract.IS_UNISWAP_VIEW();
        } catch {
          // Check for PreferredPriceOracle's secondary oracle.
          const preferredPriceOracle = new Contract(priceOracle, PreferredPriceOracleArtifact.abi, this.provider);

          let uniswapOrUniswapAnchoredViewAddress;

          try {
            uniswapOrUniswapAnchoredViewAddress = await preferredPriceOracle.secondaryOracle();
          } catch {
            throw Error("Underlying token price for this asset is not available via this oracle.");
          }

          try {
            uniswapOrUniswapAnchoredViewContract = new Contract(
              uniswapOrUniswapAnchoredViewAddress,
              JSON.parse(this.openOracleContracts["contracts/Uniswap/UniswapAnchoredView.sol:UniswapAnchoredView"].abi),
              this.provider
            );
            await uniswapOrUniswapAnchoredViewContract.IS_UNISWAP_ANCHORED_VIEW();
            isUniswapAnchoredView = true;
          } catch {
            try {
              uniswapOrUniswapAnchoredViewContract = new Contract(
                uniswapOrUniswapAnchoredViewAddress,
                JSON.parse(this.openOracleContracts["contracts/Uniswap/UniswapView.sol:UniswapView"].abi),
                this.provider
              );
              await uniswapOrUniswapAnchoredViewContract.methods.IS_UNISWAP_VIEW();
            } catch {
              throw Error(
                "Underlying token price not available via ChainlinkPriceOracleV2, and no UniswapAnchoredView or UniswapView was found."
              );
            }
          }
        }

        // Check if the token already exists
        try {
          await uniswapOrUniswapAnchoredViewContract.getTokenConfigByUnderlying(conf.underlying);
        } catch {
          // If not, add it!
          const underlyingToken = new Contract(conf.underlying, EIP20InterfaceArtifact.abi, this.provider);

          const underlyingSymbol: string = await underlyingToken.symbol();
          const underlyingDecimals: number = await underlyingToken.decimals();

          const PriceSource = {
            FIXED_ETH: 0,
            FIXED_USD: 1,
            REPORTER: 2,
            TWAP: 3,
          };

          if (conf.underlying.toLowerCase() === this.contractConfig.TOKEN_ADDRESS.W_TOKEN.toLowerCase()) {
            // WETH
            await uniswapOrUniswapAnchoredViewContract.add(
              [
                {
                  underlying: conf.underlying,
                  symbolHash: utils.solidityKeccak256(["string"], [underlyingSymbol]),
                  baseUnit: BigNumber.from(10).pow(BigNumber.from(underlyingDecimals)).toString(),
                  priceSource: PriceSource.FIXED_ETH,
                  fixedPrice: constants.WeiPerEther.toString(),
                  uniswapMarket: "0x0000000000000000000000000000000000000000",
                  isUniswapReversed: false,
                },
              ],
              { ...options }
            );
          } else if (conf.underlying === this.contractConfig.TOKEN_ADDRESS.USDC) {
            // USDC
            if (isUniswapAnchoredView) {
              await uniswapOrUniswapAnchoredViewContract.add(
                [
                  {
                    underlying: this.contractConfig.TOKEN_ADDRESS.USDC,
                    symbolHash: utils.solidityKeccak256(["string"], ["USDC"]),
                    baseUnit: BigNumber.from(1e6).toString(),
                    priceSource: PriceSource.FIXED_USD,
                    fixedPrice: 1e6,
                    uniswapMarket: "0x0000000000000000000000000000000000000000",
                    isUniswapReversed: false,
                  },
                ],
                { ...options }
              );
            } else {
              await uniswapOrUniswapAnchoredViewContract.add(
                [
                  {
                    underlying: this.contractConfig.TOKEN_ADDRESS.USDC,
                    symbolHash: utils.solidityKeccak256(["string"], ["USDC"]),
                    baseUnit: BigNumber.from(1e6).toString(),
                    priceSource: PriceSource.TWAP,
                    fixedPrice: 0,
                    uniswapMarket: "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc",
                    isUniswapReversed: false,
                  },
                ],
                { ...options }
              );
              await uniswapOrUniswapAnchoredViewContract.postPrices([this.contractConfig.TOKEN_ADDRESS.USDC], {
                ...options,
              });
            }
          } else {
            // Ask about fixed prices if UniswapAnchoredView or if UniswapView is not public; otherwise, prompt for Uniswap V2 pair
            if (isUniswapAnchoredView || !(await uniswapOrUniswapAnchoredViewContract.isPublic())) {
              // Check for fixed ETH
              const fixedEth = confirm("Should the price of this token be fixed to 1 ETH?");

              if (fixedEth) {
                await uniswapOrUniswapAnchoredViewContract.add(
                  [
                    {
                      underlying: conf.underlying,
                      symbolHash: utils.solidityKeccak256(["string"], [underlyingSymbol]),
                      baseUnit: BigNumber.from(10)
                        .pow(underlyingDecimals === 18 ? constants.WeiPerEther : BigNumber.from(underlyingDecimals))
                        .toString(),
                      priceSource: PriceSource.FIXED_ETH,
                      fixedPrice: constants.WeiPerEther.toString(),
                      uniswapMarket: "0x0000000000000000000000000000000000000000",
                      isUniswapReversed: false,
                    },
                  ],
                  { ...options }
                );
              } else {
                // Check for fixed USD
                let msg = "Should the price of this token be fixed to 1 USD?";
                if (!isUniswapAnchoredView)
                  msg +=
                    " If so, please note that you will need to run postPrices on your UniswapView for USDC instead of " +
                    underlyingSymbol +
                    " (as technically, the " +
                    underlyingSymbol +
                    " price would be fixed to 1 USDC).";
                const fixedUsd = confirm(msg);

                if (fixedUsd) {
                  const tokenConfigs = [
                    {
                      underlying: conf.underlying,
                      symbolHash: utils.solidityKeccak256(["string"], [underlyingSymbol]),
                      baseUnit: BigNumber.from(10)
                        .pow(underlyingDecimals === 18 ? constants.WeiPerEther : BigNumber.from(underlyingDecimals))
                        .toString(),
                      priceSource: PriceSource.FIXED_USD,
                      fixedPrice: BigNumber.from(1e6).toString(),
                      uniswapMarket: "0x0000000000000000000000000000000000000000",
                      isUniswapReversed: false,
                    },
                  ];

                  // UniswapView only: add USDC token config if not present so price oracle can convert from USD to ETH
                  if (!isUniswapAnchoredView) {
                    try {
                      await uniswapOrUniswapAnchoredViewContract.getTokenConfigByUnderlying(
                        this.contractConfig.TOKEN_ADDRESS.USDC
                      );
                    } catch (error) {
                      tokenConfigs.push({
                        underlying: this.contractConfig.TOKEN_ADDRESS.USDC,
                        symbolHash: utils.solidityKeccak256(["string"], ["USDC"]),
                        baseUnit: BigNumber.from(1e6).toString(),
                        priceSource: PriceSource.TWAP,
                        fixedPrice: "0",
                        uniswapMarket: "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc",
                        isUniswapReversed: false,
                      });
                    }
                  }

                  // Add token config(s)
                  await uniswapOrUniswapAnchoredViewContract.add(tokenConfigs, { ...options });

                  // UniswapView only: post USDC price
                  if (!isUniswapAnchoredView)
                    await uniswapOrUniswapAnchoredViewContract.postPrices([this.contractConfig.TOKEN_ADDRESS.USDC], {
                      ...options,
                    });
                } else await promptForUniswapV2Pair(this); // Prompt for Uniswap V2 pair
              }
            } else await promptForUniswapV2Pair(this);
          } // Prompt for Uniswap V2 pair

          // @ts-ignore
          async function promptForUniswapV2Pair(self: Fuse) {
            // Predict correct Uniswap V2 pair
            let isNotReversed = conf.underlying.toLowerCase() < self.contractConfig.TOKEN_ADDRESS.W_TOKEN.toLowerCase();
            const salt = utils.solidityKeccak256(
              ["string", "string"],
              [conf.underlying, self.contractConfig.TOKEN_ADDRESS.W_TOKEN]
            );

            let uniswapV2Pair = utils.getCreate2Address(
              self.contractConfig.FACTORY.UniswapV2_Factory,
              salt,
              self.contractConfig.PRICE_ORACLE_RUNTIME_BYTECODE_HASHES.UniswapV2_PairInit
            );

            // Double-check with user that pair is correct
            const correctUniswapV2Pair = confirm(
              "We have determined that the correct Uniswap V2 pair for " +
                (isNotReversed ? underlyingSymbol + "/ETH" : "ETH/" + underlyingSymbol) +
                " is " +
                uniswapV2Pair +
                ". Is this correct?"
            );

            if (!correctUniswapV2Pair) {
              let uniswapV2Pair = prompt("Please enter the underlying token's ETH-based Uniswap V2 pair address:");
              if (uniswapV2Pair && uniswapV2Pair.length === 0)
                throw Error(
                  isUniswapAnchoredView
                    ? "Reported prices must have a Uniswap V2 pair as an anchor!"
                    : "Non-fixed prices must have a Uniswap V2 pair from which to source prices!"
                );
              isNotReversed = confirm(
                "Press OK if the Uniswap V2 pair is " +
                  underlyingSymbol +
                  "/ETH. If it is reversed (ETH/" +
                  underlyingSymbol +
                  "), press Cancel."
              );
            }

            // Add asset to oracle
            await uniswapOrUniswapAnchoredViewContract.add(
              [
                {
                  underlying: conf.underlying,
                  symbolHash: utils.solidityKeccak256(["string"], [underlyingSymbol]),
                  baseUnit: BigNumber.from(10)
                    .pow(underlyingDecimals === 18 ? constants.WeiPerEther : BigNumber.from(underlyingDecimals))
                    .toString(),
                  priceSource: isUniswapAnchoredView ? PriceSource.REPORTER : PriceSource.TWAP,
                  fixedPrice: 0,
                  uniswapMarket: uniswapV2Pair,
                  isUniswapReversed: !isNotReversed,
                },
              ],
              { ...options }
            );

            // Post first price
            if (isUniswapAnchoredView) {
              // Post reported price or (if price has never been reported) have user report and post price
              const priceData = new Contract(
                await uniswapOrUniswapAnchoredViewContract.priceData(),
                JSON.parse(self.openOracleContracts["contracts/OpenOraclePriceData.sol:OpenOraclePriceData"].abi),
                self.provider
              );
              var reporter = await uniswapOrUniswapAnchoredViewContract.methods.reporter();
              if (BigNumber.from(await priceData.getPrice(reporter, underlyingSymbol)).gt(constants.Zero))
                await uniswapOrUniswapAnchoredViewContract.postPrices([], [], [underlyingSymbol], { ...options });
              else
                prompt(
                  "It looks like prices have never been reported for " +
                    underlyingSymbol +
                    ". Please click OK once you have reported and posted prices for" +
                    underlyingSymbol +
                    "."
                );
            } else {
              await uniswapOrUniswapAnchoredViewContract.postPrices([conf.underlying], { ...options });
            }
          }
        }
      }
    }
    */
  }

  async getPriceOracle(oracleAddress: string): Promise<string | null> {
    // Get price oracle contract name from runtime bytecode hash
    const runtimeBytecodeHash = utils.keccak256(await this.provider.getCode(oracleAddress));
    for (const [name, oracle] of Object.entries(this.oracles)) {
      const value = utils.keccak256(oracle.artifact.deployedBytecode);
      if (runtimeBytecodeHash === value) return name;
    }
    return null;
  }

  async deployRewardsDistributor(rewardToken: any, options: { from: any }) {
    const distributor = new ContractFactory(
      this.artifacts.RewardsDistributorDelegator.abi,
      this.artifacts.RewardsDistributorDelegator.bytecode,
      this.provider.getSigner()
    );
    console.log({ options, rewardToken });

    // const rdAddress = distributor.options.address;
    return await distributor.deploy({
      arguments: [options.from, rewardToken, this.chainDeployment.RewardsDistributorDelegate.address],
    });
  }

  async checkCardinality(uniswapV3Pool: string) {
    const uniswapV3PoolContract = new Contract(uniswapV3Pool, uniswapV3PoolAbiSlim);
    return (await uniswapV3PoolContract.methods.slot0().call()).observationCardinalityNext < 64;
  }

  async primeUniswapV3Oracle(uniswapV3Pool, options) {
    const uniswapV3PoolContract = new Contract(uniswapV3Pool, uniswapV3PoolAbiSlim);
    await uniswapV3PoolContract.methods.increaseObservationCardinalityNext(64).send(options);
  }

  identifyInterestRateModelName = (irmAddress: string): string | null => {
    let irmName: string | null = null;
    for (const [name, irm] of Object.entries(this.irms)) {
      if (irm.address === irmAddress) {
        irmName = name;
        return irmName;
      }
    }
    return irmName;
  };

  fetchFusePoolData = async (poolId: string | undefined, address?: string, coingeckoId?: string): Promise<FusePoolData | undefined> => {
    if (!poolId) return undefined;

    const {
      comptroller,
      name: _unfiliteredName,
      isPrivate,
    } = await this.contracts.FusePoolDirectory.pools(Number(poolId));

    const name = filterPoolName(_unfiliteredName);

    const assets: USDPricedFuseAsset[] = (
      await this.contracts.FusePoolLens.callStatic.getPoolAssetsWithData(comptroller, {
        from: address,
      })
    ).map(filterOnlyObjectProperties);

    let totalLiquidityUSD = 0;

    let totalSupplyBalanceUSD = 0;
    let totalBorrowBalanceUSD = 0;

    let totalSuppliedUSD = 0;
    let totalBorrowedUSD = 0;

    const price: number = utils.formatEther(
      // prefer rari because it has caching
      await this.getUsdPriceBN(coingeckoId, true)
    ) as any;

    const promises: Promise<boolean>[] = [];

    const comptrollerContract = new Contract(
      comptroller,
      this.chainDeployment.Comptroller.abi,
      this.provider.getSigner()
    );
    for (let i = 0; i < assets.length; i++) {
      const asset = assets[i];

      // @todo aggregate the borrow/supply guardian paused into 1
      promises.push(
        comptrollerContract.callStatic
          .borrowGuardianPaused(asset.cToken)
          .then((isPaused: boolean) => (asset.isPaused = isPaused))
      );
      promises.push(
        comptrollerContract.callStatic
          .mintGuardianPaused(asset.cToken)
          .then((isPaused: boolean) => (asset.isSupplyPaused = isPaused))
      );

      asset.supplyBalanceUSD = Number(utils.formatUnits(asset.supplyBalance)) * Number(utils.formatUnits(asset.underlyingPrice)) * price;

      asset.borrowBalanceUSD = Number(utils.formatUnits(asset.borrowBalance)) * Number(utils.formatUnits(asset.underlyingPrice)) * price;

      totalSupplyBalanceUSD += asset.supplyBalanceUSD;
      totalBorrowBalanceUSD += asset.borrowBalanceUSD;

      asset.totalSupplyUSD = Number(utils.formatUnits(asset.totalSupply)) * Number(utils.formatUnits(asset.underlyingPrice)) * price;
      asset.totalBorrowUSD = Number(utils.formatUnits(asset.totalBorrow)) * Number(utils.formatUnits(asset.underlyingPrice)) * price;

      totalSuppliedUSD += asset.totalSupplyUSD;
      totalBorrowedUSD += asset.totalBorrowUSD;

      asset.liquidityUSD = Number(utils.formatUnits(asset.liquidity)) * Number(utils.formatUnits(asset.underlyingPrice)) * price;

      totalLiquidityUSD += asset.liquidityUSD;
    }

    await Promise.all(promises);

    return {
      assets: assets.sort((a, b) => (b.liquidityUSD > a.liquidityUSD ? 1 : -1)),
      comptroller,
      name,
      isPrivate,
      totalLiquidityUSD,
      totalSuppliedUSD,
      totalBorrowedUSD,
      totalSupplyBalanceUSD,
      totalBorrowBalanceUSD,
      oracle: "",
      oracleModel: "",
      admin: "",
      isAdminWhitelisted: true,
    };
  };
}
