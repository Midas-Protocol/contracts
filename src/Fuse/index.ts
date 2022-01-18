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
import RewardsDistributorDelegatorArtifact from "../../artifacts/contracts/compound/RewardsDistributorDelegator.sol/RewardsDistributorDelegator.json";
import PreferredPriceOracleArtifact from "../../artifacts/contracts/oracles/PreferredPriceOracle.sol/PreferredPriceOracle.json";

// IRM Artifacts
import JumpRateModelArtifact from "../../artifacts/contracts/compound/JumpRateModel.sol/JumpRateModel.json";
import DAIInterestRateModelV2Artifact from "../../artifacts/contracts/compound/DAIInterestRateModelV2.sol/DAIInterestRateModelV2.json";
import WhitePaperInterestRateModelArtifact from "../../artifacts/contracts/compound/WhitePaperInterestRateModel.sol/WhitePaperInterestRateModel.json";

// Types
import { cERC20Conf, InterestRateModel, InterestRateModelConf, InterestRateModelParams, OracleConf } from "./types";
import { deployMasterPriceOracle, getDeployArgs, getOracleConf, simpleDeploy } from "./ops/oracles";
import {
  COMPTROLLER_ERROR_CODES,
  CTOKEN_ERROR_CODES,
  JUMP_RATE_MODEL_CONF,
  ORACLES,
  SIMPLE_DEPLOY_ORACLES,
} from "./config";
import { irmConfig, oracleConfig, tokenAddresses } from "../network";

type OracleConfig = {
  [contractName: string]: {
    artifact: { abi: any; bytecode: string; sourceName: string; contractName: string };
    address: string;
  };
};

type IrmConfig = OracleConfig;

type TokenAddresses = {
  [tokenName: string]: string;
};

type ChainDeployment = {
  [contractName: string]: {
    abi: any;
    address: string;
  };
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
  static ORACLES = ORACLES;
  static SIMPLE_DEPLOY_ORACLES = SIMPLE_DEPLOY_ORACLES;
  static COMPTROLLER_ERROR_CODES = COMPTROLLER_ERROR_CODES;
  static CTOKEN_ERROR_CODES = CTOKEN_ERROR_CODES;
  static JumpRateModelConf: InterestRateModelConf = JUMP_RATE_MODEL_CONF;

  public chainDeployment: ChainDeployment;
  private oracles: OracleConfig;
  private irms: IrmConfig;
  private tokenAddresses: TokenAddresses;

  constructor(web3Provider: JsonRpcProvider | Web3Provider, chainId: string) {
    this.provider = web3Provider;

    this.chainDeployment =
      Deployments[chainId] && Deployments[chainId][Object.keys(Deployments[chainId])[0]]?.contracts;
    if (!this.chainDeployment) {
      throw new Error(`Chain deployment not found for chainId ${chainId}`);
    }
    this.oracles = oracleConfig(this.chainDeployment)[chainId];
    this.irms = irmConfig(this.chainDeployment);
    this.tokenAddresses = tokenAddresses[chainId];

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
  }

  // TODO: probably should determine this by chain
  async getEthUsdPriceBN() {
    // Returns a USD price. Which means its a floating point of at least 2 decimal numbers.
    const UsdPrice: number = (
      await axios.get("https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=ethereum")
    ).data.ethereum.usd;

    // Now we turn it into a big number
    // To parse this back into USD usdPriceBN.div(constants.WeiPerEther).toString()
    return utils.parseUnits(UsdPrice.toString(), 18);
  }

  async deployPool(
    poolName: string,
    enforceWhitelist: boolean,
    closeFactor: BigNumber,
    liquidationIncentive: BigNumber,
    priceOracle: string, // Contract address
    priceOracleConf: any,
    options: any, // We might need to add sender as argument. Getting address from options will colide with the override arguments in ethers contract method calls. It doesnt take address.
    whitelist: string[] // An array of whitelisted addresses
  ): Promise<[string, string, string]> {
    // 1. Deploy new price oracle via SDK if requested
    if (Fuse.ORACLES.indexOf(priceOracle) >= 0) {
      try {
        priceOracle = (await this.deployPriceOracle(priceOracle, priceOracleConf, options)).address; // TODO: anchorMantissa / anchorPeriod
      } catch (error: any) {
        throw Error("Deployment of price oracle failed: " + (error.message ? error.message : error));
      }
    }

    // 2. Deploy Comptroller implementation if necessary
    let implementationAddress = this.chainDeployment.Comptroller.address;

    if (!implementationAddress) {
      const comptrollerContract = new ContractFactory(
        ComptrollerArtifact.abi,
        ComptrollerArtifact.bytecode,
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
    const byteCodeHash = utils.keccak256(UnitrollerArtifact.bytecode);

    const poolAddress = utils.getCreate2Address(
      this.chainDeployment.FusePoolDirectory.address,
      saltsHash,
      byteCodeHash
    );

    const unitroller = new Contract(poolAddress, UnitrollerArtifact.abi, this.provider.getSigner(options.from));

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
      let comptroller = new Contract(poolAddress, ComptrollerArtifact.abi, this.provider.getSigner(options.from));

      // Already enforced so now we just need to add the addresses
      console.log("whitelist: ", whitelist);
      await comptroller._setWhitelistStatuses(whitelist, Array(whitelist.length).fill(true));
    }

    return [poolAddress, implementationAddress, priceOracle];
  }

  private async getOracleContractFactory(contractName: string, signer?: string): Promise<ContractFactory> {
    let oracleArtifact: { abi: any; bytecode: any };
    switch (contractName) {
      case "ChainlinkPriceOracle": {
        oracleArtifact = this.oracles.ChainlinkPriceOracle.artifact;
        break;
      }
      default:
        throw Error(`Oracle contract ${contractName} not found`);
    }
    return new ContractFactory(oracleArtifact.abi, oracleArtifact.bytecode, this.provider.getSigner(signer));
  }

  async deployPriceOracle(
    model: string, // TODO: find a way to use this.ORACLES
    conf: OracleConf, // This conf depends on which comptroller model we're deploying
    options: any
  ): Promise<Contract> {
    if (!model) model = "ChainlinkPriceOracle";
    if (!conf) conf = {};

    const oracleConf = getOracleConf(this, model, conf);
    const deployArgs = getDeployArgs(this, model, oracleConf, options);

    if (Fuse.SIMPLE_DEPLOY_ORACLES.indexOf(model) >= 0) {
      const factory = await this.getOracleContractFactory(model, options.from ?? null);

      return await simpleDeploy(factory, deployArgs);
    } else {
      return await deployMasterPriceOracle(this, oracleConf, deployArgs, options);
    }
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
        modelArtifact = JumpRateModelArtifact;
        break;
      case "DAIInterestRateModelV2":
        if (!conf)
          conf = {
            jumpMultiplierPerYear: "2000000000000000000",
            kink: "900000000000000000",
          };
        deployArgs = [conf.jumpMultiplierPerYear, conf.kink, this.tokenAddresses.DAI_POT, this.tokenAddresses.DAI_JUG];
        modelArtifact = DAIInterestRateModelV2Artifact;
        break;
      case "WhitePaperInterestRateModel":
        if (!conf)
          conf = {
            baseRatePerYear: "20000000000000000",
            multiplierPerYear: "200000000000000000",
          };
        deployArgs = [conf.baseRatePerYear, conf.multiplierPerYear];
        modelArtifact = WhitePaperInterestRateModelArtifact;
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
        CEtherDelegateArtifact.abi,
        CEtherDelegateArtifact.bytecode,
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
    const comptroller = new Contract(conf.comptroller, ComptrollerArtifact.abi, this.provider.getSigner(options.from));
    console.log("Comptroller's with address: ", comptroller.address, "has admin of", await comptroller.admin());
    const comptrollerWithSigner = comptroller.connect(this.provider.getSigner(options.from));
    // const errorCode = await comptroller.callStatic._deployMarket(
    //   "0x0000000000000000000000000000000000000000",
    //   constructorData,
    //   collateralFactorBN
    // );
    // console.log(errorCode.toNumber(), Fuse.COMPTROLLER_ERROR_CODES[errorCode.toNumber()], "ERROR CODE!");

    const tx = await comptrollerWithSigner._deployMarket(
      "0x0000000000000000000000000000000000000000",
      constructorData,
      collateralFactorBN
    );

    const receipt: TransactionReceipt = await tx.wait();

    if (receipt.status != constants.One.toNumber()) {
      throw "Failed to deploy market ";
    }

    // Carlo Mazzaferro: double check this -> In FFD, the create2 address is created differently:
    // bytes32 salt = keccak256(abi.encodePacked(msg.sender, address(0), block.number));

    const saltsHash = utils.solidityKeccak256(
      ["address", "address", "uint"],
      [conf.comptroller, "0x0000000000000000000000000000000000000000", receipt.blockNumber]
    );

    const byteCodeHash = utils.keccak256(CEtherDelegatorArtifact.bytecode);

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
    const comptroller = new Contract(conf.comptroller, ComptrollerArtifact.abi, this.provider.getSigner(options.from));

    // Check for price feed assuming !bypassPriceFeedCheck
    if (!conf.bypassPriceFeedCheck) await this.checkForCErc20PriceFeed(comptroller, conf);

    // Deploy CErc20Delegate implementation contract if necessary
    if (!implementationAddress) {
      if (!conf.delegateContractName) conf.delegateContractName = "CErc20Delegate";
      let delegateContractArtifact: { abi: any; bytecode: any };
      if (conf.delegateContractName === "CErc20Delegate") {
        delegateContractArtifact = CErc20DelegateArtifact;
      } else {
        delegateContractArtifact = CEtherDelegateArtifact;
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
    const tx = await comptroller._deployMarket(false, constructorData, collateralFactorBN);
    const receipt: TransactionReceipt = await tx.wait();

    if (receipt.status != constants.One.toNumber())
      // throw "Failed to deploy market with error code: " + Fuse.COMPTROLLER_ERROR_CODES[errorCode];
      throw "Failed to deploy market ";

    const saltsHash = utils.solidityKeccak256(
      ["address", "address", "uint"],
      [conf.comptroller, conf.underlying, receipt.blockNumber]
    );
    const byteCodeHash = utils.keccak256(CErc20DelegatorArtifact.bytecode);

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
    console.log(runtimeBytecodeHash, "deployed contract bytecode hash");

    let irmModel = null;

    for (const irm of Object.values(interestRateModels)) {
      console.log(irm.RUNTIME_BYTECODE_HASH, "BCHASH1");
      console.log(runtimeBytecodeHash, "BCHASH2");
      if (runtimeBytecodeHash === irm.RUNTIME_BYTECODE_HASH) {
        irmModel = new irm();
        break;
      }
    }
    console.log(irmModel, "WHY");
    return irmModel;
  }

  async getInterestRateModel(assetAddress: string): Promise<any | undefined | null> {
    // Get interest rate model address from asset address
    const assetContract = new Contract(assetAddress, CTokenInterfacesArtifact.abi, this.provider);
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
    //1.1.2 We first assume its a ChainlinkPriceOracle.
    //1.1.3 We then try with PrefferedOracle's primary oracle i.e ChainlinkPriceOracle
    //1.1.4 We try with UniswapAnchoredView
    //1.1.5 We try with UniswapView
    //1.1.6 We try with PrefferedOracle's secondary oracle i.e UniswapAnchoredView or UniswapView
    //1.1.6

    // 2. Check

    // Get address of the priceOracle used by the comptroller
    const priceOracle: string = await comptroller.callStatic.oracle();

    // Check for a ChainlinkPriceOracle with a feed for the ERC20 Token
    let chainlinkPriceOracle: Contract;
    let chainlinkPriceFeed: boolean | undefined = undefined; // will be true if chainlink has a price feed for underlying Erc20 token

    chainlinkPriceOracle = new Contract(priceOracle, this.oracles.ChainlinkPriceOracle.artifact.abi, this.provider);

    // If underlying Erc20 is WETH use chainlinkPriceFeed, otherwise check if Chainlink supports it.
    if (conf.underlying.toLowerCase() === this.tokenAddresses.W_TOKEN.toLowerCase()) {
      chainlinkPriceFeed = true;
    } else {
      try {
        chainlinkPriceFeed = await chainlinkPriceOracle.hasPriceFeed(conf.underlying);
      } catch {}
    }

    if (chainlinkPriceFeed === undefined || !chainlinkPriceFeed) {
      const preferredPriceOracle = new Contract(priceOracle, PreferredPriceOracleArtifact.abi, this.provider);

      try {
        // Get the underlying ChainlinkOracle address of the PreferredPriceOracle
        const chainlinkPriceOracleAddress = await preferredPriceOracle.chainlinkOracle();

        // Initiate ChainlinkOracle
        chainlinkPriceOracle = new Contract(
          chainlinkPriceOracleAddress,
          this.oracles.ChainlinkPriceOracle.artifact.abi,
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
                "Underlying token price not available via ChainlinkPriceOracle, and no UniswapAnchoredView or UniswapView was found."
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
      const value = utils.keccak256(oracle.artifact.bytecode);
      if (runtimeBytecodeHash === value) return name;
    }
    return null;
  }

  async deployRewardsDistributor(rewardToken: any, options: { from: any }) {
    const distributor = new ContractFactory(
      RewardsDistributorDelegatorArtifact.abi,
      RewardsDistributorDelegatorArtifact.bytecode,
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
}
