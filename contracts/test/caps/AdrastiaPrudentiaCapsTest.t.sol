// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";

import { Comptroller } from "../../compound/Comptroller.sol";
import { IComptroller } from "../../compound/ComptrollerInterface.sol";
import { Unitroller } from "../../compound/Unitroller.sol";
import { ICErc20 } from "../../compound/CTokenInterfaces.sol";
import { CErc20Delegate } from "../../compound/CErc20Delegate.sol";
import { WhitePaperInterestRateModel } from "../../compound/WhitePaperInterestRateModel.sol";
import { ComptrollerPrudentiaCapsExt, DiamondExtension } from "../../compound/ComptrollerPrudentiaCapsExt.sol";
import { FuseFeeDistributor } from "../../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../../FusePoolDirectory.sol";
import { InterestRateModel } from "../../compound/InterestRateModel.sol";
import { CTokenFirstExtension } from "../../compound/CTokenFirstExtension.sol";
import { ComptrollerFirstExtension } from "../../compound/ComptrollerFirstExtension.sol";
import { ComptrollerV4Storage } from "../../compound/ComptrollerStorage.sol";

import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockPriceOracle } from "../../oracles/1337/MockPriceOracle.sol";

import "adrastia-periphery/rates/IHistoricalRates.sol";

abstract contract HistoricalRates is IHistoricalRates {
  struct BufferMetadata {
    uint8 start;
    uint8 end;
    uint8 size;
    uint8 maxSize;
    bool pauseUpdates; // Note: this is left for extentions, but is not used in this contract.
  }

  /// @notice Event emitted when a rate buffer's capacity is increased past the initial capacity.
  /// @dev Buffer initialization does not emit an event.
  /// @param token The token for which the rate buffer's capacity was increased.
  /// @param oldCapacity The previous capacity of the rate buffer.
  /// @param newCapacity The new capacity of the rate buffer.
  event RatesCapacityIncreased(address indexed token, uint256 oldCapacity, uint256 newCapacity);

  /// @notice Event emitted when a rate buffer's capacity is initialized.
  /// @param token The token for which the rate buffer's capacity was initialized.
  /// @param capacity The capacity of the rate buffer.
  event RatesCapacityInitialized(address indexed token, uint256 capacity);

  /// @notice Event emitted when a new rate is pushed to the rate buffer.
  /// @param token The token for which the rate was pushed.
  /// @param target The target rate.
  /// @param current The current rate, which may be different from the target rate if the rate change is capped.
  /// @param timestamp The timestamp at which the rate was pushed.
  event RateUpdated(address indexed token, uint256 target, uint256 current, uint256 timestamp);

  /// @notice An error that is thrown if we try to initialize a rate buffer that has already been initialized.
  /// @param token The token for which we tried to initialize the rate buffer.
  error BufferAlreadyInitialized(address token);

  /// @notice An error that is thrown if we try to retrieve a rate at an invalid index.
  /// @param token The token for which we tried to retrieve the rate.
  /// @param index The index of the rate that we tried to retrieve.
  /// @param size The size of the rate buffer.
  error InvalidIndex(address token, uint256 index, uint256 size);

  /// @notice An error that is thrown if we try to decrease the capacity of a rate buffer.
  /// @param token The token for which we tried to decrease the capacity of the rate buffer.
  /// @param amount The capacity that we tried to decrease the rate buffer to.
  /// @param currentCapacity The current capacity of the rate buffer.
  error CapacityCannotBeDecreased(address token, uint256 amount, uint256 currentCapacity);

  /// @notice An error that is thrown if we try to increase the capacity of a rate buffer past the maximum capacity.
  /// @param token The token for which we tried to increase the capacity of the rate buffer.
  /// @param amount The capacity that we tried to increase the rate buffer to.
  /// @param maxCapacity The maximum capacity of the rate buffer.
  error CapacityTooLarge(address token, uint256 amount, uint256 maxCapacity);

  /// @notice An error that is thrown if we try to retrieve more rates than are available in the rate buffer.
  /// @param token The token for which we tried to retrieve the rates.
  /// @param size The size of the rate buffer.
  /// @param minSizeRequired The minimum size of the rate buffer that we require.
  error InsufficientData(address token, uint256 size, uint256 minSizeRequired);

  /// @notice The initial capacity of the rate buffer.
  uint8 internal immutable initialBufferCardinality;

  /// @notice Maps a token to its metadata.
  mapping(address => BufferMetadata) internal rateBufferMetadata;

  /// @notice Maps a token to a buffer of rates.
  mapping(address => RateLibrary.Rate[]) internal rateBuffers;

  /**
   * @notice Constructs the HistoricalRates contract with a specified initial buffer capacity.
   * @param initialBufferCardinality_ The initial capacity of the rate buffer.
   */
  constructor(uint8 initialBufferCardinality_) {
    initialBufferCardinality = initialBufferCardinality_;
  }

  /// @inheritdoc IHistoricalRates
  function getRateAt(address token, uint256 index) external view virtual override returns (RateLibrary.Rate memory) {
    BufferMetadata memory meta = rateBufferMetadata[token];

    if (index >= meta.size) {
      revert InvalidIndex(token, index, meta.size);
    }

    uint256 bufferIndex = meta.end < index ? meta.end + meta.size - index : meta.end - index;

    return rateBuffers[token][bufferIndex];
  }

  /// @inheritdoc IHistoricalRates
  function getRates(address token, uint256 amount) external view virtual override returns (RateLibrary.Rate[] memory) {
    return _getRates(token, amount, 0, 1);
  }

  /// @inheritdoc IHistoricalRates
  function getRates(
    address token,
    uint256 amount,
    uint256 offset,
    uint256 increment
  ) external view virtual override returns (RateLibrary.Rate[] memory) {
    return _getRates(token, amount, offset, increment);
  }

  /// @inheritdoc IHistoricalRates
  function getRatesCount(address token) external view override returns (uint256) {
    return rateBufferMetadata[token].size;
  }

  /// @inheritdoc IHistoricalRates
  function getRatesCapacity(address token) external view virtual override returns (uint256) {
    uint256 maxSize = rateBufferMetadata[token].maxSize;
    if (maxSize == 0) return initialBufferCardinality;

    return maxSize;
  }

  /// @param amount The new capacity of rates for the token. Must be greater than the current capacity, but
  ///   less than 256.
  /// @inheritdoc IHistoricalRates
  function setRatesCapacity(address token, uint256 amount) external virtual {
    _setRatesCapacity(token, amount);
  }

  /**
   * @dev Internal function to set the capacity of the rate buffer for a token.
   * @param token The token for which to set the new capacity.
   * @param amount The new capacity of rates for the token. Must be greater than the current capacity, but
   * less than 256.
   */
  function _setRatesCapacity(address token, uint256 amount) internal virtual {
    BufferMetadata storage meta = rateBufferMetadata[token];

    if (amount < meta.maxSize) revert CapacityCannotBeDecreased(token, amount, meta.maxSize);
    if (amount > type(uint8).max) revert CapacityTooLarge(token, amount, type(uint8).max);

    RateLibrary.Rate[] storage rateBuffer = rateBuffers[token];

    // Add new slots to the buffer
    uint256 capacityToAdd = amount - meta.maxSize;
    for (uint256 i = 0; i < capacityToAdd; ++i) {
      // Push a dummy rate with non-zero values to put most of the gas cost on the caller
      rateBuffer.push(RateLibrary.Rate({ target: 1, current: 1, timestamp: 1 }));
    }

    if (meta.maxSize != amount) {
      emit RatesCapacityIncreased(token, meta.maxSize, amount);

      // Update the metadata
      meta.maxSize = uint8(amount);
    }
  }

  /**
   * @dev Internal function to get historical rates with specified amount, offset, and increment.
   * @param token The token for which to retrieve the rates.
   * @param amount The number of historical rates to retrieve.
   * @param offset The number of rates to skip before starting to collect the rates.
   * @param increment The step size between the rates to collect.
   * @return observations An array of Rate structs containing the retrieved historical rates.
   */
  function _getRates(
    address token,
    uint256 amount,
    uint256 offset,
    uint256 increment
  ) internal view virtual returns (RateLibrary.Rate[] memory) {
    if (amount == 0) return new RateLibrary.Rate[](0);

    BufferMetadata memory meta = rateBufferMetadata[token];
    if (meta.size <= (amount - 1) * increment + offset)
      revert InsufficientData(token, meta.size, (amount - 1) * increment + offset + 1);

    RateLibrary.Rate[] memory observations = new RateLibrary.Rate[](amount);

    uint256 count = 0;

    for (
      uint256 i = meta.end < offset ? meta.end + meta.size - offset : meta.end - offset;
      count < amount;
      i = (i < increment) ? (i + meta.size) - increment : i - increment
    ) {
      observations[count++] = rateBuffers[token][i];
    }

    return observations;
  }

  /**
   * @dev Internal function to initialize rate buffers for a token.
   * @param token The token for which to initialize the rate buffer.
   */
  function initializeBuffers(address token) internal virtual {
    if (rateBuffers[token].length != 0) {
      revert BufferAlreadyInitialized(token);
    }

    BufferMetadata storage meta = rateBufferMetadata[token];

    // Initialize the buffers
    RateLibrary.Rate[] storage observationBuffer = rateBuffers[token];

    for (uint256 i = 0; i < initialBufferCardinality; ++i) {
      observationBuffer.push();
    }

    // Initialize the metadata
    meta.start = 0;
    meta.end = 0;
    meta.size = 0;
    meta.maxSize = initialBufferCardinality;
    meta.pauseUpdates = false;

    emit RatesCapacityInitialized(token, meta.maxSize);
  }

  /**
   * @dev Internal function to push a new rate data into the rate buffer and update metadata accordingly.
   * @param token The token for which to push the new rate data.
   * @param rate The Rate struct containing target rate, current rate, and timestamp data to be pushed.
   */
  function push(address token, RateLibrary.Rate memory rate) internal virtual {
    BufferMetadata storage meta = rateBufferMetadata[token];

    if (meta.size == 0) {
      if (meta.maxSize == 0) {
        // Initialize the buffers
        initializeBuffers(token);
      }
    } else {
      meta.end = (meta.end + 1) % meta.maxSize;
    }

    rateBuffers[token][meta.end] = rate;

    emit RateUpdated(token, rate.target, rate.current, block.timestamp);

    if (meta.size < meta.maxSize && meta.end == meta.size) {
      // We are at the end of the array and we have not yet filled it
      meta.size++;
    } else {
      // start was just overwritten
      meta.start = (meta.start + 1) % meta.size;
    }
  }
}

contract PrudentiaStub is HistoricalRates {
  constructor() HistoricalRates(2) {}

  function stubPush(ICErc20 cToken, uint64 rate) public {
    push(address(cToken), RateLibrary.Rate({ target: rate, current: rate, timestamp: uint32(block.timestamp) }));
  }
}

contract AdrastiaPrudentiaCapsTest is BaseTest {
  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;

  IComptroller comptroller;

  WhitePaperInterestRateModel interestModel;
  MockPriceOracle priceOracle;

  MockERC20 underlyingToken1;
  ICErc20 cToken1;

  MockERC20 underlyingToken2;
  ICErc20 cToken2;

  CErc20Delegate cErc20Delegate;

  PrudentiaStub prudentia;

  function setUp() public {
    // Deploy admin contracts
    fuseAdmin = new FuseFeeDistributor();
    fuseAdmin.initialize(1e16);
    fusePoolDirectory = new FusePoolDirectory();
    address[] memory emptyAddresses;
    fusePoolDirectory.initialize(false, emptyAddresses);

    // Deploy comptroller logic
    Comptroller comptrollerLogic = new Comptroller(payable(address(fuseAdmin)));

    // Deploy underlying tokens
    underlyingToken1 = new MockERC20("UnderlyingToken1", "UT1", 18);
    underlyingToken1.mint(address(this), 1000000e18); // 1M tokens
    underlyingToken2 = new MockERC20("UnderlyingToken2", "UT2", 18);
    underlyingToken2.mint(address(this), 1000000e18); // 1M tokens

    // Deploy cToken delegates
    cErc20Delegate = new CErc20Delegate();

    // Deploy price oracle
    priceOracle = new MockPriceOracle(10);

    // Deploy IRM
    interestModel = new WhitePaperInterestRateModel(2343665, 1e18, 1e18);

    // Deploy comptroller
    address[] memory unitroller = new address[](1);
    unitroller[0] = address(comptrollerLogic);
    address[] memory addressZero = new address[](1);
    addressZero[0] = address(0);
    bool[] memory boolTrue = new bool[](1);
    boolTrue[0] = true;
    bool[] memory boolFalse = new bool[](1);
    boolFalse[0] = false;
    fuseAdmin._editComptrollerImplementationWhitelist(addressZero, unitroller, boolTrue);
    DiamondExtension[] memory extensions = new DiamondExtension[](2);
    extensions[0] = new ComptrollerFirstExtension();
    extensions[1] = new ComptrollerPrudentiaCapsExt();
    fuseAdmin._setComptrollerExtensions(address(comptrollerLogic), extensions);
    (, address comptrollerAddress) = fusePoolDirectory.deployPool(
      "TestPool", // name
      address(comptrollerLogic), // implementation address
      abi.encode(payable(address(fuseAdmin))), // constructor args
      false, // whitelist enforcement
      0.1e18, // close factor = 10%
      1.1e18, // liquidation incentive = 110%
      address(priceOracle) // price oracle
    );
    Unitroller(payable(comptrollerAddress))._acceptAdmin();
    comptroller = IComptroller(comptrollerAddress);

    // Setup CErc20Delegate whitelist
    DiamondExtension[] memory cErc20DelegateExtensions = new DiamondExtension[](1);
    cErc20DelegateExtensions[0] = new CTokenFirstExtension();
    fuseAdmin._setCErc20DelegateExtensions(address(cErc20Delegate), cErc20DelegateExtensions);
    address[] memory oldCErc20Implementations = new address[](1);
    oldCErc20Implementations[0] = address(0);
    address[] memory newCErc20Implementations = new address[](1);
    newCErc20Implementations[0] = address(cErc20Delegate);
    fuseAdmin._editCErc20DelegateWhitelist(oldCErc20Implementations, newCErc20Implementations, boolFalse, boolTrue);

    // Deploy cToken1
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken1), // underlying token
        comptroller, // comptroller
        payable(address(fuseAdmin)), // admin
        InterestRateModel(address(interestModel)), // interest rate model
        "cToken 1", // cToken name
        "CT1", // cToken symbol
        address(cErc20Delegate), // implementation (CErc20Delegate)
        "", // become implementation data
        uint256(1), // reserve factor
        uint256(0) // admin fee
      ),
      0.9e18 // collateral factor = 90%
    );

    // Deploy cToken2
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken2), // underlying token
        comptroller, // comptroller
        payable(address(fuseAdmin)), // admin
        InterestRateModel(address(interestModel)), // interest rate model
        "cToken 2", // cToken name
        "CT2", // cToken symbol
        address(cErc20Delegate), // implementation (CErc20Delegate)
        "", // become implementation data
        uint256(1), // reserve factor
        uint256(0) // admin fee
      ),
      0.9e18 // collateral factor = 90%
    );

    // Store the cToken addresses
    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    assertEq(allMarkets.length, 2);
    cToken1 = allMarkets[0];
    cToken2 = allMarkets[1];

    // Deploy Prudentia
    prudentia = new PrudentiaStub();
  }

  function test_NativeCaps_UnrestrictedSupply() public {
    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
  }

  function test_NativeCaps_RestrictedSupply() public {
    uint256 cap = 9999e18; // supply cap of 9,999
    uint256 mintAmount = 10000e18; // mint of 10,000

    // Set a native supply cap for cToken1
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = cap;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    vm.expectRevert();
    cToken1.mint(mintAmount); // FAIL: Mint
  }

  function test_NativeCaps_UnrestrictedBorrow() public {
    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Borrow
    cToken2.borrow(1000e18); // Borrow 1,000 cToken2
  }

  function test_NativeCaps_RestrictedBorrow() public {
    uint256 cap = 999e18; // borrow cap of 999
    uint256 borrowAmount = 1000e18; // borrow of 1,000

    // Set a native borrow cap for cToken2
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = cap;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Borrow
    vm.expectRevert();
    cToken2.borrow(borrowAmount); // FAIL: Borrow
  }

  /*
   * Prudentia caps tests with an offset of 0
   */

  function test_Prudentia_Supply_Unrestricted() public {
    uint64 cap = 0; // Unrestricted supply cap
    uint256 mintAmount = 9999e18; // mint of 9,999

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Set Prudentia supply cap for cToken1
    prudentia.stubPush(cToken1, cap);

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(mintAmount); // Mint
  }

  function test_Prudentia_Supply_MissingRate() public {
    uint256 mintAmount = 9999e18; // mint of 9,999

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Note: Prudentia doesn't have a supply cap for cToken1

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    vm.expectRevert();
    cToken1.mint(mintAmount); // FAIL: Mint
  }

  function test_Prudentia_Supply_MissingRate_WithRateConfiguredForAnotherCToken() public {
    uint256 mintAmount = 9999e18; // mint of 9,999

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Set Prudentia supply cap for cToken2
    prudentia.stubPush(cToken2, 0); // Unrestricted supply cap for cToken2

    // Note: Prudentia doesn't have a supply cap for cToken1

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    vm.expectRevert();
    cToken1.mint(mintAmount); // FAIL: Mint
  }

  function test_Prudentia_Supply_LessThanCap() public {
    uint64 cap = 10000; // supply cap of 10,000
    uint256 mintAmount = 9999e18; // mint of 9,999

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Set Prudentia supply cap for cToken1
    prudentia.stubPush(cToken1, cap);

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(mintAmount); // Mint
  }

  function test_Prudentia_Supply_GreaterThanCap() public {
    uint64 cap = 10000; // supply cap of 10,000
    uint256 mintAmount = 10001e18; // mint of 10,001

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Set Prudentia supply cap for cToken1
    prudentia.stubPush(cToken1, cap);

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    vm.expectRevert();
    cToken1.mint(mintAmount); // FAIL: Mint
  }

  function test_Prudentia_Borrow_LessThanCap() public {
    uint64 cap = 1000; // borrow cap of 1,000
    uint256 borrowAmount = 999e18; // borrow of 999

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Set Prudentia borrow cap for cToken2
    prudentia.stubPush(cToken2, cap);

    // Borrow
    cToken2.borrow(borrowAmount); // Borrow
  }

  function test_Prudentia_Borrow_Unrestricted() public {
    uint64 cap = 0; // Unrestricted borrow cap
    uint256 borrowAmount = 999e18; // borrow of 999

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Set Prudentia borrow cap for cToken2
    prudentia.stubPush(cToken2, cap);

    // Borrow
    cToken2.borrow(borrowAmount); // Borrow
  }

  function test_Prudentia_Borrow_MissingRate() public {
    uint64 cap = 0; // Unrestricted borrow cap
    uint256 borrowAmount = 999e18; // borrow of 999

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Note: Prudentia doesn't have a borrow cap for cToken2

    // Borrow
    vm.expectRevert();
    cToken2.borrow(borrowAmount); // FAIL: Borrow
  }

  function test_Prudentia_Borrow_MissingRate_WithRateConfiguredForAnotherCToken() public {
    uint256 borrowAmount = 999e18; // borrow of 999

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Set Prudentia borrow cap for cToken1
    prudentia.stubPush(cToken1, 0); // Unrestricted borrow cap for cToken1

    // Note: Prudentia doesn't have a borrow cap for cToken2

    // Borrow
    vm.expectRevert();
    cToken2.borrow(borrowAmount); // FAIL: Borrow
  }

  function test_Prudentia_Borrow_GreaterThanCap() public {
    uint64 cap = 1000; // borrow cap of 1,000
    uint256 borrowAmount = 1001e18; // borrow of 1,001

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 0 })
    );

    // Set Prudentia borrow cap for cToken2
    prudentia.stubPush(cToken2, cap);

    // Borrow
    vm.expectRevert();
    cToken2.borrow(borrowAmount); // FAIL: Borrow
  }

  /*
   * Prudentia caps tests with an offset of 1
   */

  function test_Prudentia_Supply_Unrestricted_Offset1() public {
    uint64 cap = 0; // Unrestricted supply cap
    uint256 mintAmount = 9999e18; // mint of 9,999

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 1 })
    );

    // Set Prudentia supply cap for cToken1
    prudentia.stubPush(cToken1, cap); // Unrestricted cap at index 1 (this should be used)
    prudentia.stubPush(cToken1, 1); // Highly restrictive cap at index 0. If this cap is used, the test should fail.

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(mintAmount); // Mint
  }

  function test_Prudentia_Supply_MissingRate_Offset1() public {
    uint256 mintAmount = 9999e18; // mint of 9,999

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 1 })
    );

    // Note: Prudentia doesn't have a supply cap for cToken1 at index 1 (the offset)
    prudentia.stubPush(cToken1, 0); // Unrestricted cap at index 0. If this cap is used, the test should fail.

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    vm.expectRevert();
    cToken1.mint(mintAmount); // FAIL: Mint
  }

  function test_Prudentia_Supply_LessThanCap_Offset1() public {
    uint64 cap = 10000; // supply cap of 10,000
    uint256 mintAmount = 9999e18; // mint of 9,999

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 1 })
    );

    // Set Prudentia supply cap for cToken1
    prudentia.stubPush(cToken1, cap); // The cap we're using at index 1 (this should be used)
    prudentia.stubPush(cToken1, 1); // Highly restrictive cap at index 0. If this cap is used, the test should fail.

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(mintAmount); // Mint
  }

  function test_Prudentia_Supply_GreaterThanCap_Offset1() public {
    uint64 cap = 10000; // supply cap of 10,000
    uint256 mintAmount = 10001e18; // mint of 10,001

    // Set a native supply cap for cToken1
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken1;
    uint256[] memory supplyCaps = new uint256[](1);
    supplyCaps[0] = 1;
    comptroller._setMarketSupplyCaps(cTokens, supplyCaps);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 1 })
    );

    // Set Prudentia supply cap for cToken1
    prudentia.stubPush(cToken1, cap); // The cap we're using at index 1 (this should be used)
    prudentia.stubPush(cToken1, 0); // Unrestricted cap at index 0. If this cap is used, the test should fail.

    // Mint
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    vm.expectRevert();
    cToken1.mint(mintAmount); // FAIL: Mint
  }

  function test_Prudentia_Borrow_LessThanCap_Offset1() public {
    uint64 cap = 1000; // borrow cap of 1,000
    uint256 borrowAmount = 999e18; // borrow of 999

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 1 })
    );

    // Set Prudentia borrow cap for cToken2
    prudentia.stubPush(cToken2, cap); // The cap we're using at index 1 (this should be used)
    prudentia.stubPush(cToken2, 1); // Highly restrictive cap at index 0. If this cap is used, the test should fail.

    // Borrow
    cToken2.borrow(borrowAmount); // Borrow
  }

  function test_Prudentia_Borrow_Unrestricted_Offset1() public {
    uint64 cap = 0; // Unrestricted borrow cap
    uint256 borrowAmount = 999e18; // borrow of 999

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 1 })
    );

    // Set Prudentia borrow cap for cToken2
    prudentia.stubPush(cToken2, cap); // The cap we're using at index 1 (this should be used)
    prudentia.stubPush(cToken2, 1); // Highly restrictive cap at index 0. If this cap is used, the test should fail.

    // Borrow
    cToken2.borrow(borrowAmount); // Borrow
  }

  function test_Prudentia_Borrow_MissingRate_Offset1() public {
    uint256 borrowAmount = 999e18; // borrow of 999

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 1 })
    );

    // Note: Prudentia doesn't have a borrow cap for cToken2 at index 1 (the offset)
    prudentia.stubPush(cToken2, 0); // Unrestricted cap at index 0. If this cap is used, the test should fail.

    // Borrow
    vm.expectRevert();
    cToken2.borrow(borrowAmount); // FAIL: Borrow
  }

  function test_Prudentia_Borrow_GreaterThanCap_Offset1() public {
    uint64 cap = 1000; // borrow cap of 1,000
    uint256 borrowAmount = 1001e18; // borrow of 1,001

    // Set a native borrow cap for cToken2
    // This should be ignored since we're using Prudentia
    ICErc20[] memory cTokens = new ICErc20[](1);
    cTokens[0] = cToken2;
    uint256[] memory borrowCaps = new uint256[](1);
    borrowCaps[0] = 1;
    comptroller._setMarketBorrowCaps(cTokens, borrowCaps);

    // Mint cToken1 and cToken2
    underlyingToken1.approve(address(cToken1), type(uint256).max); // Approve max
    cToken1.mint(10000e18); // Mint 10,000 cToken1
    underlyingToken2.approve(address(cToken2), type(uint256).max); // Approve max
    cToken2.mint(10000e18); // Mint 10,000 cToken2

    // Use cToken1 as collateral
    address[] memory enterMarkets = new address[](1);
    enterMarkets[0] = address(cToken1);
    comptroller.enterMarkets(enterMarkets);

    // Enable Prudentia
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(
      ComptrollerV4Storage.PrudentiaConfig({ controller: address(prudentia), offset: 1 })
    );

    // Set Prudentia borrow cap for cToken2
    prudentia.stubPush(cToken2, cap); // The cap we're using at index 1 (this should be used)
    prudentia.stubPush(cToken2, 0); // Unrestricted cap at index 0. If this cap is used, the test should fail.

    // Borrow
    vm.expectRevert();
    cToken2.borrow(borrowAmount); // FAIL: Borrow
  }

  /*
  Additional ComptrollerPrudentiaCapsExt tests
  */

  event NewBorrowCapConfig(
    ComptrollerV4Storage.PrudentiaConfig oldConfig,
    ComptrollerV4Storage.PrudentiaConfig newConfig
  );

  event NewSupplyCapConfig(
    ComptrollerV4Storage.PrudentiaConfig oldConfig,
    ComptrollerV4Storage.PrudentiaConfig newConfig
  );

  function test_Prudentia_SupplyCapConfig() public {
    ComptrollerV4Storage.PrudentiaConfig memory oldConfig = ComptrollerV4Storage.PrudentiaConfig({
      controller: address(0),
      offset: 0
    });
    ComptrollerV4Storage.PrudentiaConfig memory newConfig = ComptrollerV4Storage.PrudentiaConfig({
      controller: address(prudentia),
      offset: 0
    });

    // Setup expectation of the following event
    vm.expectEmit(false, false, false, true);
    emit NewSupplyCapConfig(oldConfig, newConfig);

    // Set supply cap config
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(newConfig);

    // Get the supply cap config
    ComptrollerV4Storage.PrudentiaConfig memory current = ComptrollerPrudentiaCapsExt(address(comptroller))
      .getSupplyCapConfig();

    assertEq(newConfig.controller, current.controller, "controller");
    assertEq(newConfig.offset, current.offset, "offset");
  }

  function test_Prudentia_BorrowCapConfig() public {
    ComptrollerV4Storage.PrudentiaConfig memory oldConfig = ComptrollerV4Storage.PrudentiaConfig({
      controller: address(0),
      offset: 0
    });
    ComptrollerV4Storage.PrudentiaConfig memory newConfig = ComptrollerV4Storage.PrudentiaConfig({
      controller: address(prudentia),
      offset: 0
    });

    // Setup expectation of the following event
    vm.expectEmit(false, false, false, true);
    emit NewBorrowCapConfig(oldConfig, newConfig);

    // Set borrow cap config
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(newConfig);

    // Get the borrow cap config
    ComptrollerV4Storage.PrudentiaConfig memory current = ComptrollerPrudentiaCapsExt(address(comptroller))
      .getBorrowCapConfig();

    assertEq(newConfig.controller, current.controller, "controller");
    assertEq(newConfig.offset, current.offset, "offset");
  }

  function test_Prudentia_SetSupplyCapConfig_OnlyAdmin() public {
    ComptrollerV4Storage.PrudentiaConfig memory newConfig = ComptrollerV4Storage.PrudentiaConfig({
      controller: address(prudentia),
      offset: 0
    });

    // Set supply cap config
    vm.prank(address(7));
    vm.expectRevert("!admin");
    ComptrollerPrudentiaCapsExt(address(comptroller))._setSupplyCapConfig(newConfig);
  }

  function test_Prudentia_SetBorrowCapConfig_OnlyAdmin() public {
    ComptrollerV4Storage.PrudentiaConfig memory newConfig = ComptrollerV4Storage.PrudentiaConfig({
      controller: address(prudentia),
      offset: 0
    });

    // Set supply cap config
    vm.prank(address(7));
    vm.expectRevert("!admin");
    ComptrollerPrudentiaCapsExt(address(comptroller))._setBorrowCapConfig(newConfig);
  }
}
