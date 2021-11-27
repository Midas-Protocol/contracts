var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
// Ethers
import { BigNumber, constants, Contract, ContractFactory, utils } from "ethers";
// Axios
import axios from "axios";
// ABIs
import fusePoolDirectoryAbi from "./abi/FusepoolDirectory.json";
import fusePoolLensAbi from "./abi/FusePoolLens.json";
import fuseSafeLiquidatorAbi from "./abi/FuseSafeLiquidator.json";
import fuseFeeDistributorAbi from "./abi/FuseFeeDistributor.json";
import fusePoolLensSecondaryAbi from "./abi/FusePoolLensSecondary.json";
// Contracts
import CompoundMini from "./contracts/compound-protocol.min.json";
import openOracle from "./contracts/open-oracle.min.json";
import Oracle from "./contracts/oracles.min.json";
// InterestRate Models
import JumpRateModel from "./irm/JumpRateModel";
import JumpRateModelV2 from "./irm/JumpRateModelV2";
import DAIInterestRateModelV2 from "./irm/DAIInterestRateModelV2";
import WhitePaperInterestRateModel from "./irm/WhitePaperInterestRateModel";
import uniswapV3PoolAbiSlim from "./abi/UniswapV3Pool.slim.json";
import initializableClonesAbi from "./abi/InitializableClones.json";
import { Interface } from "@ethersproject/abi";
import { COMPTROLLER_ERROR_CODES, CTOKEN_ERROR_CODES, JUMP_RATE_MODEL_CONF, ORACLES } from "./config";
export default class Fuse {
    constructor(web3Provider, contractConfig) {
        this.contractConfig = contractConfig;
        this.provider = web3Provider;
        this.constants = constants;
        this.compoundContractsMini = CompoundMini.contracts;
        // this.compoundContracts = Compound.contracts;
        this.openOracleContracts = openOracle.contracts;
        this.oracleContracts = Oracle.contracts;
        this.contracts = {
            FusePoolDirectory: new Contract(this.contractConfig.FUSE_CONTRACT_ADDRESSES.FusePoolDirectory, fusePoolDirectoryAbi, this.provider),
            FusePoolLens: new Contract(this.contractConfig.FUSE_CONTRACT_ADDRESSES.FusePoolLens, fusePoolLensAbi, this.provider),
            FusePoolLensSecondary: new Contract(this.contractConfig.FUSE_CONTRACT_ADDRESSES.FusePoolLensSecondary, fusePoolLensSecondaryAbi, this.provider),
            FuseSafeLiquidator: new Contract(this.contractConfig.FUSE_CONTRACT_ADDRESSES.FuseSafeLiquidator, fuseSafeLiquidatorAbi, this.provider),
            FuseFeeDistributor: new Contract(this.contractConfig.FUSE_CONTRACT_ADDRESSES.FuseFeeDistributor, fuseFeeDistributorAbi, this.provider),
        };
        this.getEthUsdPriceBN = function () {
            return __awaiter(this, void 0, void 0, function* () {
                // Returns a USD price. Which means its a floating point of at least 2 decimal numbers.
                const UsdPrice = (yield axios.get("https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=ethereum")).data.ethereum.usd;
                // Now we turn it into a big number
                // To parse this back into USD usdPriceBN.div(constants.WeiPerEther).toString()
                return utils.parseUnits(UsdPrice.toString(), 18);
            });
        };
        this.deployPool = function (poolName, enforceWhitelist, closeFactor, maxAssets, liquidationIncentive, priceOracle, // Contract address
        priceOracleConf, options, // We might need to add sender as argument. Getting address from options will colide with the override arguments in ethers contract method calls. It doesnt take address.
        whitelist // An array of whitelisted addresses
        ) {
            return __awaiter(this, void 0, void 0, function* () {
                // 1. Deploy new price oracle via SDK if requested
                if (Fuse.ORACLES.indexOf(priceOracle) >= 0) {
                    try {
                        priceOracle = (yield this.deployPriceOracle(priceOracle, priceOracleConf, options)).address; // TODO: anchorMantissa / anchorPeriod
                    }
                    catch (error) {
                        throw Error("Deployment of price oracle failed: " + (error.message ? error.message : error));
                    }
                }
                // 2. Deploy Comptroller implementation if necessary
                let implementationAddress = this.contractConfig.COMPOUND_CONTRACT_ADDRESSES.Comptroller;
                if (!implementationAddress) {
                    const comptrollerContract = new ContractFactory(JSON.parse(this.compoundContractsMini["contracts/Comptroller.sol:Comptroller"].abi), this.contracts["contracts/Comptroller.sol:Comptroller"].bin, this.provider.getSigner());
                    const deployedComptroller = yield comptrollerContract.deploy(Object.assign({}, options));
                    implementationAddress = deployedComptroller.options.address;
                }
                //3. Register new pool with FusePoolDirectory
                let receipt;
                try {
                    const contract = this.contracts.FusePoolDirectory.connect(this.provider.getSigner());
                    receipt = yield contract.deployPool(poolName, implementationAddress, enforceWhitelist, closeFactor, maxAssets, liquidationIncentive, priceOracle);
                }
                catch (error) {
                    throw Error("Deployment and registration of new Fuse pool failed: " + (error.message ? error.message : error));
                }
                //4. Compute Unitroller address
                const saltsHash = utils.solidityKeccak256(["address", "string", "uint"], [options.from, poolName, receipt.deployTransaction.blockNumber]);
                const byteCodeHash = utils.keccak256("0x" + this.contracts["contracts/Unitroller.sol:Unitroller"].bin);
                let poolAddress = utils.getCreate2Address(this.contractConfig.FUSE_CONTRACT_ADDRESSES.FusePoolDirectory, saltsHash, byteCodeHash);
                let unitroller = new Contract(poolAddress, JSON.parse(this.contracts["contracts/Unitroller.sol:Unitroller"].abi), this.provider);
                // Accept admin status via Unitroller
                try {
                    yield unitroller._acceptAdmin();
                }
                catch (error) {
                    throw Error("Accepting admin status failed: " + (error.message ? error.message : error));
                }
                // Whitelist
                if (enforceWhitelist) {
                    let comptroller = new Contract(poolAddress, JSON.parse(this.compoundContractsMini["contracts/Comptroller.sol:Comptroller"].abi), this.provider);
                    // Already enforced so now we just need to add the addresses
                    yield comptroller._setWhitelistStatuses(whitelist, Array(whitelist.length).fill(true));
                }
                return [poolAddress, implementationAddress, priceOracle];
            });
        };
        this.deployPriceOracle = function (model, // TODO: find a way to use this.ORACLES
        conf, // This conf depends on which comptroller model we're deploying
        options) {
            return __awaiter(this, void 0, void 0, function* () {
                let deployArgs = [];
                let priceOracleContract;
                let deployedPriceOracle;
                let oracleFactoryContract;
                if (!model)
                    model = "ChainlinkPriceOracle";
                if (!conf)
                    conf = {};
                switch (model) {
                    case "ChainlinkPriceOracle":
                        deployArgs = [conf.maxSecondsBeforePriceIsStale ? conf.maxSecondsBeforePriceIsStale : 0];
                        priceOracleContract = new ContractFactory(this.oracleContracts["ChainlinkPriceOracle"].abi, this.oracleContracts["ChainlinkPriceOracle"].bin, this.provider.getSigner());
                        deployedPriceOracle = yield priceOracleContract.deploy(deployArgs, Object.assign({}, options));
                        break;
                    case "UniswapLpTokenPriceOracle":
                        deployArgs = [!!conf.useRootOracle];
                        priceOracleContract = new ContractFactory(this.oracleContracts["UniswapLpTokenPriceOracle"].abi, this.oracleContracts["UniswapLpTokenPriceOracle"].bin, this.provider.getSigner());
                        deployedPriceOracle = priceOracleContract.deploy(deployArgs, Object.assign({}, options));
                        break;
                    case "UniswapTwapPriceOracle": // Uniswap V2 TWAPs
                        // Input Validation
                        if (!conf.uniswapV2Factory)
                            conf.uniswapV2Factory = this.contractConfig.FACTORY.UniswapV2_Factory;
                        deployArgs = [
                            this.contractConfig.PUBLIC_PRICE_ORACLE_CONTRACT_ADDRESSES.UniswapTwapPriceOracle_RootContract,
                            conf.uniswapV2Factory,
                        ]; // Default to official Uniswap V2 factory
                        // Deploy Oracle
                        priceOracleContract = new ContractFactory(this.oracleContracts["UniswapTwapPriceOracle"].abi, this.oracleContracts["UniswapTwapPriceOracle"].bin, this.provider.getSigner());
                        deployedPriceOracle = yield priceOracleContract.deploy(deployArgs, { options });
                        break;
                    case "UniswapTwapPriceOracleV2": // Uniswap V2 TWAPs
                        // Input validation
                        if (!conf.uniswapV2Factory)
                            conf.uniswapV2Factory = this.contractConfig.FACTORY.UniswapV2_Factory;
                        // Check for existing oracle
                        oracleFactoryContract = new Contract(this.contractConfig.FACTORY.UniswapTwapPriceOracleV2_Factory, this.oracleContracts.UniswapTwapPriceOracleV2Factory.abi, this.provider.getSigner());
                        deployedPriceOracle = yield oracleFactoryContract.oracles(this.contractConfig.FACTORY.UniswapV2_Factory);
                        // Deploy if oracle does not exist
                        if (deployedPriceOracle === "0x0000000000000000000000000000000000000000") {
                            yield oracleFactoryContract.deploy(this.contractConfig.FACTORY.UniswapV2_Factory);
                            deployedPriceOracle = yield oracleFactoryContract.oracles(this.contractConfig.FACTORY.UniswapV2_Factory);
                        }
                        break;
                    case "ChainlinkPriceOracleV2":
                        priceOracleContract = new ContractFactory(this.oracleContracts["ChainlinkPriceOracleV2"].abi, this.oracleContracts["ChainlinkPriceOracleV2"].bin, this.provider.getSigner());
                        deployArgs = [conf.admin ? conf.admin : options.from, !!conf.canAdminOverwrite];
                        deployedPriceOracle = yield priceOracleContract.deploy(deployArgs, Object.assign({}, options));
                        break;
                    case "UniswapV3TwapPriceOracle":
                        // Input validation
                        if (!conf.uniswapV3Factory)
                            conf.uniswapV3Factory = this.contractConfig.FACTORY.UniswapV3_Factory;
                        if ([500, 3000, 10000].indexOf(parseInt(conf.feeTier)) < 0)
                            throw Error("Invalid fee tier passed to UniswapV3TwapPriceOracle deployment.");
                        // Deploy oracle
                        deployArgs = [conf.uniswapV3Factory, conf.feeTier]; // Default to official Uniswap V3 factory
                        priceOracleContract = new ContractFactory(this.oracleContracts["UniswapV3TwapPriceOracle"].abi, this.oracleContracts["UniswapV3TwapPriceOracle"].bin, this.provider.getSigner());
                        deployedPriceOracle = yield priceOracleContract.deploy(deployArgs, Object.assign({}, options));
                        break;
                    case "UniswapV3TwapPriceOracleV2":
                        // Input validation
                        if (!conf.uniswapV3Factory)
                            conf.uniswapV3Factory = this.contractConfig.FACTORY.UniswapV3_Factory;
                        if ([500, 3000, 10000].indexOf(parseInt(conf.feeTier)) < 0)
                            throw Error("Invalid fee tier passed to UniswapV3TwapPriceOracleV2 deployment.");
                        // Check for existing oracle
                        oracleFactoryContract = new Contract(this.contractConfig.FACTORY.UniswapV3TwapPriceOracleV2_Factory, this.oracleContracts.UniswapV3TwapPriceOracleV2Factory.abi, this.provider.getSigner());
                        deployedPriceOracle = yield oracleFactoryContract.methods
                            .oracles(conf.uniswapV3Factory, conf.feeTier, conf.baseToken)
                            .call();
                        // Deploy if oracle does not exist
                        if (deployedPriceOracle == "0x0000000000000000000000000000000000000000") {
                            yield oracleFactoryContract.deploy(conf.uniswapV3Factory, conf.feeTier, conf.baseToken);
                            deployedPriceOracle = yield oracleFactoryContract.oracles(conf.uniswapV3Factory, conf.feeTier, conf.baseToken);
                        }
                        break;
                    case "FixedTokenPriceOracle":
                        priceOracleContract = new ContractFactory(this.oracleContracts["FixedTokenPriceOracle"].abi, this.oracleContracts["FixedTokenPriceOracle"].bin, this.provider.getSigner());
                        deployArgs = [conf.baseToken];
                        deployedPriceOracle = yield priceOracleContract.deploy(deployArgs, Object.assign({}, options));
                        break;
                    case "MasterPriceOracle":
                        const initializableClones = new Contract(this.contractConfig.COMPOUND_CONTRACT_ADDRESSES.InitializableClones, initializableClonesAbi, this.provider.getSigner());
                        const masterPriceOracle = new Interface(Oracle["MasterPriceOracle"].abi);
                        deployArgs = [
                            conf.underlyings ? conf.underlyings : [],
                            conf.oracles ? conf.oracles : [],
                            conf.defaultOracle ? conf.defaultOracle : "0x0000000000000000000000000000000000000000",
                            conf.admin ? conf.admin : options.from,
                            !!conf.canAdminOverwrite,
                        ];
                        const initializerData = masterPriceOracle.encodeDeploy(deployArgs);
                        const receipt = yield initializableClones.clone(
                        // this.contractConfig
                        this.contractConfig.FUSE_CONTRACT_ADDRESSES.MasterPriceOracleImplementation, initializerData);
                        deployedPriceOracle = new Contract(Oracle["MasterPriceOracle"].abi, receipt.events["Deployed"].returnValues.instance);
                        break;
                    case "SimplePriceOracle":
                        priceOracleContract = new ContractFactory(JSON.parse(this.contracts["contracts/SimplePriceOracle.sol:SimplePriceOracle"].abi), this.contracts["contracts/SimplePriceOracle.sol:SimplePriceOracle"].bin, this.provider.getSigner());
                        deployedPriceOracle = yield priceOracleContract.deploy(Object.assign({}, options));
                        break;
                    default:
                        priceOracleContract = new ContractFactory(this.oracleContracts[model].abi, this.oracleContracts[model].bin, this.provider.getSigner());
                        deployedPriceOracle = yield priceOracleContract.deploy(Object.assign({}, options));
                        break;
                }
                return deployedPriceOracle;
                //return deployedPriceOracle.options.address;
            });
        };
        this.deployComptroller = function (closeFactor, maxAssets, liquidationIncentive, priceOracle, // Contract address
        implementationAddress, // Address of comptroller if its already deployed
        options) {
            return __awaiter(this, void 0, void 0, function* () {
                let deployedComptroller;
                // 1. Deploy comptroller if necessary
                if (!implementationAddress) {
                    const comptrollerContract = new Contract(JSON.parse(this.compoundContractsMini["contracts/Comptroller.sol:Comptroller"].abi), this.compoundContractsMini["contracts/Comptroller.sol:Comptroller"].bin, this.provider.getSigner());
                    deployedComptroller = yield comptrollerContract.deploy(...options);
                    implementationAddress = deployedComptroller.options.address;
                }
                // 2. Get Unitroller to set the comptroller implementation address for the pool
                const unitrollerContract = new ContractFactory(JSON.parse(this.compoundContractsMini["contracts/Unitroller.sol:Unitroller"].abi), this.compoundContractsMini["contracts/Unitroller.sol:Unitroller"].bin, this.provider.getSigner());
                const deployedUnitroller = yield unitrollerContract.deploy(Object.assign({}, options));
                yield deployedUnitroller._setPendingImplementation(deployedComptroller.options.address, Object.assign({}, options));
                // Comptroller becomes unitroller.
                yield deployedComptroller._become(deployedUnitroller.address, Object.assign({}, options));
                deployedComptroller.address = deployedUnitroller.address;
                // Set comptroller configuration
                if (closeFactor)
                    yield deployedComptroller._setCloseFactor(closeFactor, Object.assign({}, options));
                if (maxAssets)
                    yield deployedComptroller._setMaxAssets(maxAssets, Object.assign({}, options));
                if (liquidationIncentive)
                    yield deployedComptroller.methods._setLiquidationIncentive(liquidationIncentive, Object.assign({}, options));
                if (priceOracle)
                    yield deployedComptroller._setPriceOracle(priceOracle, Object.assign({}, options));
                return [deployedUnitroller.options.address, implementationAddress];
            });
        };
        this.deployAsset = function (conf, collateralFactor, reserveFactor, // Amount of accrue interest that will go to the pool's reserves. Usually 0.1
        adminFee, options, bypassPriceFeedCheck // ?
        ) {
            return __awaiter(this, void 0, void 0, function* () {
                let assetAddress;
                let implementationAddress;
                let receipt;
                // Deploy new interest rate model via SDK if requested
                if ([
                    "WhitePaperInterestRateModel",
                    "JumpRateModel",
                    "JumpRateModelV2",
                    "ReactiveJumpRateModelV2",
                    "DAIInterestRateModelV2",
                ].indexOf(conf.interestRateModel) >= 0) {
                    try {
                        conf.interestRateModel = yield this.deployInterestRateModel(conf.interestRateModel, conf.interestRateModelParams, options); // TODO: anchorMantissa
                    }
                    catch (error) {
                        throw Error("Deployment of interest rate model failed: " + (error.message ? error.message : error));
                    }
                }
                // Deploy new asset to existing pool via SDK
                try {
                    [assetAddress, implementationAddress, receipt] = yield this.deployCToken(conf, collateralFactor, reserveFactor, adminFee, options, bypassPriceFeedCheck);
                }
                catch (error) {
                    throw Error("Deployment of asset to Fuse pool failed: " + (error.message ? error.message : error));
                }
                return [assetAddress, implementationAddress, conf.interestRateModel, receipt];
            });
        };
        this.deployInterestRateModel = function (model, conf, options) {
            return __awaiter(this, void 0, void 0, function* () {
                // Default model = JumpRateModel
                if (!model) {
                    model = "JumpRateModel";
                }
                // Get deployArgs
                let deployArgs = [];
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
                            this.contractConfig.TOKEN_ADDRESS.DAI_POT,
                            this.contractConfig.TOKEN_ADDRESS.DAI_JUG,
                        ];
                        break;
                    case "WhitePaperInterestRateModel":
                        if (!conf)
                            conf = {
                                baseRatePerYear: "20000000000000000",
                                multiplierPerYear: "200000000000000000",
                            };
                        deployArgs = [conf.baseRatePerYear, conf.multiplierPerYear];
                        break;
                }
                // Deploy InterestRateModel
                const interestRateModelContract = new ContractFactory(JSON.parse(this.compoundContractsMini["contracts/" + model + ".sol:" + model].abi), this.compoundContractsMini["contracts/" + model + ".sol:" + model].bin, this.provider.getSigner());
                const deployedInterestRateModel = yield interestRateModelContract.deploy(deployArgs, Object.assign({}, options));
                return deployedInterestRateModel.options.address;
            });
        };
        this.deployCToken = function (conf, collateralFactor, reserveFactor, adminFee, options, bypassPriceFeedCheck) {
            return __awaiter(this, void 0, void 0, function* () {
                // BigNumbers
                const reserveFactorBN = BigNumber.from(reserveFactor);
                const adminFeeBN = BigNumber.from(adminFee);
                const collateralFactorBN = utils.parseUnits(collateralFactor, 18); // TODO: find out if this is a number or string. If its a number, parseUnits will not work. Also parse Units works if number is between 0 - 0.9
                // Check collateral factor
                if (!collateralFactorBN.gte(constants.Zero) || collateralFactorBN.gt(utils.parseUnits("0.9", 18)))
                    throw Error("Collateral factor must range from 0 to 0.9.");
                // Check reserve factor + admin fee + Fuse fee
                if (!reserveFactorBN.gte(constants.Zero))
                    throw Error("Reserve factor cannot be negative.");
                if (!adminFeeBN.gte(constants.Zero))
                    throw Error("Admin fee cannot be negative.");
                // If reserveFactor or adminFee is greater than zero, we get fuse fee.
                // Sum of reserveFactor and adminFee should not be greater than fuse fee. ? i think
                if (reserveFactorBN.gt(constants.Zero) || adminFeeBN.gt(constants.Zero)) {
                    const fuseFee = yield this.contracts.FuseFeeDistributor.callStatic.interestFeeRate();
                    if (reserveFactorBN.add(adminFeeBN).add(BigNumber.from(fuseFee)).gt(constants.WeiPerEther))
                        throw Error("Sum of reserve factor and admin fee should range from 0 to " + (1 - parseInt(fuseFee) / 1e18) + ".");
                }
                return conf.underlying !== undefined &&
                    conf.underlying !== null &&
                    conf.underlying.length > 0 &&
                    !BigNumber.from(conf.underlying).isZero()
                    ? yield this.deployCErc20(conf, collateralFactor, reserveFactor, adminFee, options, bypassPriceFeedCheck, this.contractConfig.COMPOUND_CONTRACT_ADDRESSES.CErc20Delegate
                        ? this.contractConfig.COMPOUND_CONTRACT_ADDRESSES.CErc20Delegate
                        : undefined)
                    : yield this.deployCEther(conf, collateralFactor, reserveFactor, adminFee, this.contractConfig.COMPOUND_CONTRACT_ADDRESSES.CEther20Delegate
                        ? this.contractConfig.COMPOUND_CONTRACT_ADDRESSES.CEther20Delegate
                        : null, options);
            });
        };
        this.deployCEther = function (conf, supportMarket, collateralFactor, reserveFactor, adminFee, options, implementationAddress) {
            return __awaiter(this, void 0, void 0, function* () {
                // Deploy CEtherDelegate implementation contract if necessary
                if (!implementationAddress) {
                    const cEtherDelegateFactory = new ContractFactory(JSON.parse(this.compoundContractsMini["contracts/CEtherDelegate.sol:CEtherDelegate"].abi), this.compoundContractsMini["contracts/CEtherDelegate.sol:CEtherDelegate"].bin, this.provider.getSigner());
                    const cEtherDelegateDeployed = yield cEtherDelegateFactory.deploy();
                    implementationAddress = cEtherDelegateDeployed.address;
                }
                // Deploy CEtherDelegator proxy contract
                let deployArgs = [
                    conf.comptroller,
                    conf.interestRateModel,
                    conf.name,
                    conf.symbol,
                    implementationAddress,
                    "0x00",
                    reserveFactor ? reserveFactor.toString() : 0,
                    adminFee ? adminFee.toString() : 0,
                ];
                const abiCoder = new utils.AbiCoder();
                const constructorData = abiCoder.encode(["address", "address", "string", "string", "address", "bytes", "uint256", "uint256"], deployArgs);
                const comptroller = new Contract(conf.comptroller, JSON.parse(this.compoundContractsMini["contracts/Comptroller.sol:Comptroller"].abi), this.provider.getSigner());
                const errorCode = yield comptroller._deployMarket("0x0000000000000000000000000000000000000000", constructorData, collateralFactor);
                if (errorCode != constants.Zero)
                    throw "Failed to deploy market with error code: " + Fuse.COMPTROLLER_ERROR_CODES[errorCode];
                const receipt = yield comptroller._deployMarket("0x0000000000000000000000000000000000000000", constructorData, collateralFactor);
                const saltsHash = utils.solidityKeccak256(["address", "address", "uint"], [conf.comptroller, "0x0000000000000000000000000000000000000000", receipt.blockNumber]);
                const byteCodeHash = utils.keccak256("0x" + this.compoundContractsMini["contracts/CEtherDelegator.sol:CEtherDelegator"].bin);
                const cEtherDelegatorAddress = utils.getCreate2Address(this.contractConfig.FUSE_CONTRACT_ADDRESSES.FuseFeeDistributor, saltsHash, byteCodeHash);
                // Return cToken proxy and implementation contract addresses
                return [cEtherDelegatorAddress, implementationAddress, receipt];
            });
        };
        this.deployCErc20 = function (conf, collateralFactor, reserveFactor, adminFee, options, bypassPriceFeedCheck, implementationAddress // cERC20Delegate implementation
        ) {
            return __awaiter(this, void 0, void 0, function* () {
                // Get Comptroller
                const comptroller = new Contract(conf.comptroller, JSON.parse(this.compoundContractsMini["contracts/Comptroller.sol:Comptroller"].abi));
                // Check for price feed assuming !bypassPriceFeedCheck
                if (!bypassPriceFeedCheck)
                    yield this.checkForCErc20PriceFeed(comptroller, conf);
                // Deploy CErc20Delegate implementation contract if necessary
                if (!implementationAddress) {
                    if (!conf.delegateContractName)
                        conf.delegateContractName = "CErc20Delegate";
                    const cErc20Delegate = new ContractFactory(JSON.parse(this.compoundContractsMini["contracts/" + conf.delegateContractName + ".sol:" + conf.delegateContractName]
                        .abi), this.compoundContractsMini["contracts/" + conf.delegateContractName + ".sol:" + conf.delegateContractName].bin, this.provider.getSigner());
                    const cErc20DelegateDeployed = yield cErc20Delegate.deploy();
                    implementationAddress = cErc20DelegateDeployed.address;
                }
                let deployArgs = [
                    conf.underlying,
                    conf.comptroller,
                    conf.interestRateModel,
                    conf.name,
                    conf.symbol,
                    implementationAddress,
                    "0x00",
                    reserveFactor ? reserveFactor.toString() : 0,
                    adminFee ? adminFee.toString() : 0,
                ];
                const abiCoder = new utils.AbiCoder();
                const constructorData = abiCoder.encode(["address", "address", "address", "string", "string", "address", "bytes", "uint256", "uint256"], deployArgs);
                const errorCode = yield comptroller._deployMarket(false, constructorData, collateralFactor);
                if (errorCode != constants.Zero)
                    throw "Failed to deploy market with error code: " + Fuse.COMPTROLLER_ERROR_CODES[errorCode];
                const receipt = yield comptroller._deployMarket(false, constructorData, collateralFactor);
                const saltsHash = utils.solidityKeccak256(["address", "address", "uint"], [conf.comptroller, conf.underlying, receipt.blockNumber]);
                const byteCodeHash = utils.keccak256("0x" + this.compoundContractsMini["contracts/Unitroller.sol:Unitroller"]);
                const cErc20DelegatorAddress = utils.getCreate2Address(this.contractConfig.FUSE_CONTRACT_ADDRESSES.FuseFeeDistributor, saltsHash, byteCodeHash);
                // Return cToken proxy and implementation contract addresses
                return [cErc20DelegatorAddress, implementationAddress, receipt];
            });
        };
        this.identifyPriceOracle = function (priceOracleAddress) {
            return __awaiter(this, void 0, void 0, function* () {
                // Get PriceOracle type from runtime bytecode hash
                const runtimeBytecodeHash = utils.keccak256(yield this.provider.getCode(priceOracleAddress));
                for (const oracleContractName of Object.keys(this.contractConfig.PRICE_ORACLE_RUNTIME_BYTECODE_HASHES)) {
                    const valueOrArr = this.contractConfig.PRICE_ORACLE_RUNTIME_BYTECODE_HASHES[oracleContractName];
                    if (Array.isArray(valueOrArr)) {
                        for (const potentialHash of valueOrArr)
                            if (runtimeBytecodeHash == potentialHash)
                                return oracleContractName;
                    }
                    else {
                        if (runtimeBytecodeHash == valueOrArr)
                            return oracleContractName;
                    }
                }
                return null;
            });
        };
        this.identifyInterestRateModel = function (interestRateModelAddress) {
            return __awaiter(this, void 0, void 0, function* () {
                // Get interest rate model type from runtime bytecode hash and init class
                const interestRateModels = {
                    JumpRateModel: JumpRateModel,
                    JumpRateModelV2: JumpRateModelV2,
                    DAIInterestRateModelV2: DAIInterestRateModelV2,
                    WhitePaperInterestRateModel: WhitePaperInterestRateModel,
                };
                const runtimeBytecodeHash = utils.keccak256(yield this.provider.getCode(interestRateModelAddress));
                // Find ONE interes ratemodel and return thath
                // compare runtimeByrecodeHash with
                //
                let irm;
                outerLoop: for (const model of Object.keys(interestRateModels)) {
                    if (interestRateModels[model].RUNTIME_BYTECODE_HASHES !== undefined) {
                        for (const hash of interestRateModels[model].RUNTIME_BYTECODE_HASHES) {
                            if (runtimeBytecodeHash === hash) {
                                irm = new interestRateModels[model]();
                                console.log(irm);
                                break outerLoop;
                            }
                        }
                    }
                    else if (runtimeBytecodeHash === interestRateModels[model].RUNTIME_BYTECODE_HASH) {
                        irm = new interestRateModels[model]();
                        break;
                    }
                }
                console.log(irm, "WHY");
                return irm;
            });
        };
        this.getInterestRateModel = function (assetAddress) {
            return __awaiter(this, void 0, void 0, function* () {
                // Get interest rate model address from asset address
                const assetContract = new Contract(assetAddress, JSON.parse(this.compoundContractsMini["contracts/CTokenInterfaces.sol:CTokenInterface"].abi), this.provider);
                const interestRateModelAddress = yield assetContract.callStatic.interestRateModel();
                const interestRateModel = yield this.identifyInterestRateModel(interestRateModelAddress);
                yield interestRateModel.init(interestRateModelAddress, assetAddress, this.provider);
                return interestRateModel;
            });
        };
        this.checkForCErc20PriceFeed = function (comptroller, conf, options) {
            return __awaiter(this, void 0, void 0, function* () {
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
                const priceOracle = yield comptroller.callStatic.oracle();
                // Check for a ChainlinkPriceOracle with a feed for the ERC20 Token
                let chainlinkPriceOracle;
                let chainlinkPriceFeed = undefined; // will be true if chainlink has a price feed for underlying Erc20 token
                chainlinkPriceOracle = new Contract(priceOracle, this.oracleContracts["ChainlinkPriceOracle"].abi, this.provider);
                // If underlying Erc20 is WETH use chainlinkPriceFeed, otherwise check if Chainlink supports it.
                if (conf.underlying.toLowerCase() === this.contractConfig.TOKEN_ADDRESS.W_TOKEN.toLowerCase()) {
                    chainlinkPriceFeed = true;
                }
                else {
                    try {
                        chainlinkPriceFeed = yield chainlinkPriceOracle.hasPriceFeed(conf.underlying);
                    }
                    catch (_a) { }
                }
                if (chainlinkPriceFeed === undefined || !chainlinkPriceFeed) {
                    const preferredPriceOracle = new Contract(priceOracle, this.oracleContracts["PreferredPriceOracle"].abi, this.provider);
                    try {
                        // Get the underlying ChainlinkOracle address of the PreferredPriceOracle
                        const chainlinkPriceOracleAddress = yield preferredPriceOracle.chainlinkOracle();
                        // Initiate ChainlinkOracle
                        chainlinkPriceOracle = new Contract(chainlinkPriceOracleAddress, this.oracleContracts["ChainlinkPriceOracle"].abi, this.provider);
                        // Check if chainlink has an available price feed for the Erc20Token
                        chainlinkPriceFeed = yield chainlinkPriceOracle.hasPriceFeed(conf.underlying);
                    }
                    catch (_b) { }
                }
                if (chainlinkPriceFeed === undefined || !chainlinkPriceFeed) {
                    // Check if we can get a UniswapAnchoredView
                    var isUniswapAnchoredView = false;
                    let uniswapOrUniswapAnchoredViewContract;
                    try {
                        uniswapOrUniswapAnchoredViewContract = new Contract(priceOracle, JSON.parse(this.openOracleContracts["contracts/Uniswap/UniswapAnchoredView.sol:UniswapAnchoredView"].abi), this.provider);
                        yield uniswapOrUniswapAnchoredViewContract.IS_UNISWAP_ANCHORED_VIEW();
                        isUniswapAnchoredView = true;
                    }
                    catch (_c) {
                        try {
                            uniswapOrUniswapAnchoredViewContract = new Contract(priceOracle, JSON.parse(this.openOracleContracts["contracts/Uniswap/UniswapView.sol:UniswapView"].abi), this.provider);
                            yield uniswapOrUniswapAnchoredViewContract.IS_UNISWAP_VIEW();
                        }
                        catch (_d) {
                            // Check for PreferredPriceOracle's secondary oracle.
                            const preferredPriceOracle = new Contract(priceOracle, this.oracleContracts["PreferredPriceOracle"].abi, this.provider);
                            let uniswapOrUniswapAnchoredViewAddress;
                            try {
                                uniswapOrUniswapAnchoredViewAddress = yield preferredPriceOracle.secondaryOracle();
                            }
                            catch (_e) {
                                throw Error("Underlying token price for this asset is not available via this oracle.");
                            }
                            try {
                                uniswapOrUniswapAnchoredViewContract = new Contract(uniswapOrUniswapAnchoredViewAddress, JSON.parse(this.openOracleContracts["contracts/Uniswap/UniswapAnchoredView.sol:UniswapAnchoredView"].abi), this.provider);
                                yield uniswapOrUniswapAnchoredViewContract.IS_UNISWAP_ANCHORED_VIEW();
                                isUniswapAnchoredView = true;
                            }
                            catch (_f) {
                                try {
                                    uniswapOrUniswapAnchoredViewContract = new Contract(uniswapOrUniswapAnchoredViewAddress, JSON.parse(this.openOracleContracts["contracts/Uniswap/UniswapView.sol:UniswapView"].abi), this.provider);
                                    yield uniswapOrUniswapAnchoredViewContract.methods.IS_UNISWAP_VIEW();
                                }
                                catch (_g) {
                                    throw Error("Underlying token price not available via ChainlinkPriceOracle, and no UniswapAnchoredView or UniswapView was found.");
                                }
                            }
                        }
                        // Check if the token already exists
                        try {
                            yield uniswapOrUniswapAnchoredViewContract.getTokenConfigByUnderlying(conf.underlying);
                        }
                        catch (_h) {
                            // If not, add it!
                            const underlyingToken = new Contract(conf.underlying, JSON.parse(this.compoundContractsMini["contracts/EIP20Interface.sol:EIP20Interface"].abi), this.provider);
                            const underlyingSymbol = yield underlyingToken.symbol();
                            const underlyingDecimals = yield underlyingToken.decimals();
                            const PriceSource = {
                                FIXED_ETH: 0,
                                FIXED_USD: 1,
                                REPORTER: 2,
                                TWAP: 3,
                            };
                            if (conf.underlying.toLowerCase() === this.contractConfig.TOKEN_ADDRESS.W_TOKEN.toLowerCase()) {
                                // WETH
                                yield uniswapOrUniswapAnchoredViewContract.add([
                                    {
                                        underlying: conf.underlying,
                                        symbolHash: utils.solidityKeccak256(["string"], [underlyingSymbol]),
                                        baseUnit: BigNumber.from(10).pow(BigNumber.from(underlyingDecimals)).toString(),
                                        priceSource: PriceSource.FIXED_ETH,
                                        fixedPrice: constants.WeiPerEther.toString(),
                                        uniswapMarket: "0x0000000000000000000000000000000000000000",
                                        isUniswapReversed: false,
                                    },
                                ], Object.assign({}, options));
                            }
                            else if (conf.underlying === this.contractConfig.TOKEN_ADDRESS.USDC) {
                                // USDC
                                if (isUniswapAnchoredView) {
                                    yield uniswapOrUniswapAnchoredViewContract.add([
                                        {
                                            underlying: this.contractConfig.TOKEN_ADDRESS.USDC,
                                            symbolHash: utils.solidityKeccak256(["string"], ["USDC"]),
                                            baseUnit: BigNumber.from(1e6).toString(),
                                            priceSource: PriceSource.FIXED_USD,
                                            fixedPrice: 1e6,
                                            uniswapMarket: "0x0000000000000000000000000000000000000000",
                                            isUniswapReversed: false,
                                        },
                                    ], Object.assign({}, options));
                                }
                                else {
                                    yield uniswapOrUniswapAnchoredViewContract.add([
                                        {
                                            underlying: this.contractConfig.TOKEN_ADDRESS.USDC,
                                            symbolHash: utils.solidityKeccak256(["string"], ["USDC"]),
                                            baseUnit: BigNumber.from(1e6).toString(),
                                            priceSource: PriceSource.TWAP,
                                            fixedPrice: 0,
                                            uniswapMarket: "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc",
                                            isUniswapReversed: false,
                                        },
                                    ], Object.assign({}, options));
                                    yield uniswapOrUniswapAnchoredViewContract.postPrices([this.contractConfig.TOKEN_ADDRESS.USDC], Object.assign({}, options));
                                }
                            }
                            else {
                                // Ask about fixed prices if UniswapAnchoredView or if UniswapView is not public; otherwise, prompt for Uniswap V2 pair
                                if (isUniswapAnchoredView || !(yield uniswapOrUniswapAnchoredViewContract.isPublic())) {
                                    // Check for fixed ETH
                                    const fixedEth = confirm("Should the price of this token be fixed to 1 ETH?");
                                    if (fixedEth) {
                                        yield uniswapOrUniswapAnchoredViewContract.add([
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
                                        ], Object.assign({}, options));
                                    }
                                    else {
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
                                                    yield uniswapOrUniswapAnchoredViewContract.getTokenConfigByUnderlying(this.contractConfig.TOKEN_ADDRESS.USDC);
                                                }
                                                catch (error) {
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
                                            yield uniswapOrUniswapAnchoredViewContract.add(tokenConfigs, Object.assign({}, options));
                                            // UniswapView only: post USDC price
                                            if (!isUniswapAnchoredView)
                                                yield uniswapOrUniswapAnchoredViewContract.postPrices([this.contractConfig.TOKEN_ADDRESS.USDC], Object.assign({}, options));
                                        }
                                        else
                                            yield promptForUniswapV2Pair(this); // Prompt for Uniswap V2 pair
                                    }
                                }
                                else
                                    yield promptForUniswapV2Pair(this);
                            } // Prompt for Uniswap V2 pair
                            function promptForUniswapV2Pair(self) {
                                return __awaiter(this, void 0, void 0, function* () {
                                    // Predict correct Uniswap V2 pair
                                    let isNotReversed = conf.underlying.toLowerCase() < self.contractConfig.TOKEN_ADDRESS.W_TOKEN.toLowerCase();
                                    const salt = utils.solidityKeccak256(["string", "string"], [conf.underlying, self.contractConfig.TOKEN_ADDRESS.W_TOKEN]);
                                    let uniswapV2Pair = utils.getCreate2Address(self.contractConfig.FACTORY.UniswapV2_Factory, salt, self.contractConfig.PRICE_ORACLE_RUNTIME_BYTECODE_HASHES.UniswapV2_PairInit);
                                    // Double-check with user that pair is correct
                                    const correctUniswapV2Pair = confirm("We have determined that the correct Uniswap V2 pair for " +
                                        (isNotReversed ? underlyingSymbol + "/ETH" : "ETH/" + underlyingSymbol) +
                                        " is " +
                                        uniswapV2Pair +
                                        ". Is this correct?");
                                    if (!correctUniswapV2Pair) {
                                        let uniswapV2Pair = prompt("Please enter the underlying token's ETH-based Uniswap V2 pair address:");
                                        if (uniswapV2Pair && uniswapV2Pair.length === 0)
                                            throw Error(isUniswapAnchoredView
                                                ? "Reported prices must have a Uniswap V2 pair as an anchor!"
                                                : "Non-fixed prices must have a Uniswap V2 pair from which to source prices!");
                                        isNotReversed = confirm("Press OK if the Uniswap V2 pair is " +
                                            underlyingSymbol +
                                            "/ETH. If it is reversed (ETH/" +
                                            underlyingSymbol +
                                            "), press Cancel.");
                                    }
                                    // Add asset to oracle
                                    yield uniswapOrUniswapAnchoredViewContract.add([
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
                                    ], Object.assign({}, options));
                                    // Post first price
                                    if (isUniswapAnchoredView) {
                                        // Post reported price or (if price has never been reported) have user report and post price
                                        const priceData = new Contract(yield uniswapOrUniswapAnchoredViewContract.priceData(), JSON.parse(self.openOracleContracts["contracts/OpenOraclePriceData.sol:OpenOraclePriceData"].abi), self.provider);
                                        var reporter = yield uniswapOrUniswapAnchoredViewContract.methods.reporter();
                                        if (BigNumber.from(yield priceData.getPrice(reporter, underlyingSymbol)).gt(constants.Zero))
                                            yield uniswapOrUniswapAnchoredViewContract.postPrices([], [], [underlyingSymbol], Object.assign({}, options));
                                        else
                                            prompt("It looks like prices have never been reported for " +
                                                underlyingSymbol +
                                                ". Please click OK once you have reported and posted prices for" +
                                                underlyingSymbol +
                                                ".");
                                    }
                                    else {
                                        yield uniswapOrUniswapAnchoredViewContract.postPrices([conf.underlying], Object.assign({}, options));
                                    }
                                });
                            }
                        }
                    }
                }
            });
        };
        this.getPriceOracle = function (oracleAddress) {
            return __awaiter(this, void 0, void 0, function* () {
                // Get price oracle contract name from runtime bytecode hash
                const runtimeBytecodeHash = utils.keccak256(yield this.provider.getCode(oracleAddress));
                for (const model of Object.keys(this.contractConfig.PRICE_ORACLE_RUNTIME_BYTECODE_HASHES)) {
                    if (runtimeBytecodeHash === this.contractConfig.PRICE_ORACLE_RUNTIME_BYTECODE_HASHES[model])
                        return model;
                    return null;
                }
            });
        };
        this.deployRewardsDistributor = function (rewardToken, options) {
            return __awaiter(this, void 0, void 0, function* () {
                const distributor = new ContractFactory(JSON.parse(this.compoundContractsMini["contracts/RewardsDistributorDelegator.sol:RewardsDistributorDelegator"].abi), this.compoundContractsMini["contracts/RewardsDistributorDelegator.sol:RewardsDistributorDelegator"].bin, this.provider.getSigner());
                console.log({ options, rewardToken });
                // const rdAddress = distributor.options.address;
                return yield distributor.deploy({
                    arguments: [
                        options.from,
                        rewardToken,
                        this.contractConfig.COMPOUND_CONTRACT_ADDRESSES.RewardsDistributorDelegate,
                    ],
                });
            });
        };
        this.checkCardinality = function (uniswapV3Pool) {
            return __awaiter(this, void 0, void 0, function* () {
                const uniswapV3PoolContract = new Contract(uniswapV3Pool, uniswapV3PoolAbiSlim);
                return (yield uniswapV3PoolContract.methods.slot0().call()).observationCardinalityNext < 64;
            });
        };
        this.primeUniswapV3Oracle = function (uniswapV3Pool, options) {
            return __awaiter(this, void 0, void 0, function* () {
                const uniswapV3PoolContract = new Contract(uniswapV3Pool, uniswapV3PoolAbiSlim);
                yield uniswapV3PoolContract.methods.increaseObservationCardinalityNext(64).send(options);
            });
        };
        this.identifyInterestRateModelName = (irmAddress) => {
            let name = "";
            Object.entries(this.contractConfig.PUBLIC_INTEREST_RATE_MODEL_CONTRACT_ADDRESSES).forEach(([key, value]) => {
                if (value === irmAddress) {
                    name = key;
                }
            });
            return name;
        };
    }
}
Fuse.ORACLES = ORACLES;
Fuse.COMPTROLLER_ERROR_CODES = COMPTROLLER_ERROR_CODES;
Fuse.CTOKEN_ERROR_CODES = CTOKEN_ERROR_CODES;
Fuse.JumpRateModelConf = JUMP_RATE_MODEL_CONF;
