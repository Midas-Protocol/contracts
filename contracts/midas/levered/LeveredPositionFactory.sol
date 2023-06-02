// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { ILeveredPositionFactory } from "./ILeveredPositionFactory.sol";
import { LeveredPosition } from "./LeveredPosition.sol";
import { SafeOwnableUpgradeable } from "../SafeOwnableUpgradeable.sol";
import { IFuseFeeDistributor } from "../../compound/IFuseFeeDistributor.sol";
import { ILiquidatorsRegistry } from "../../liquidators/registry/ILiquidatorsRegistry.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { IComptroller, IPriceOracle } from "../../external/compound/IComptroller.sol";
import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LeveredPositionFactory is ILeveredPositionFactory, SafeOwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using EnumerableSet for EnumerableSet.AddressSet;

  error PairNotWhitelisted();
  error NoSuchPosition();
  error PositionNotClosed();

  // @notice maximum slippage in swaps, in bps
  uint256 public constant MAX_SLIPPAGE = 900; // 9%

  IFuseFeeDistributor public fuseFeeDistributor;
  ILiquidatorsRegistry public liquidatorsRegistry;
  uint256 public blocksPerYear;

  mapping(address => EnumerableSet.AddressSet) private positionsByAccount;
  EnumerableSet.AddressSet private collateralMarkets;
  mapping(ICErc20 => EnumerableSet.AddressSet) private borrowableMarketsByCollateral;

  mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => uint256)) internal conversionSlippage;

  EnumerableSet.AddressSet private accountsWithOpenPositions;

  /*----------------------------------------------------------------
                        Initializer Functions
  ----------------------------------------------------------------*/

  constructor() {
    _disableInitializers();
  }

  function initialize(
    IFuseFeeDistributor _fuseFeeDistributor,
    ILiquidatorsRegistry _registry,
    uint256 _blocksPerYear
  ) public initializer {
    __SafeOwnable_init(msg.sender);
    fuseFeeDistributor = _fuseFeeDistributor;
    liquidatorsRegistry = _registry;
    blocksPerYear = _blocksPerYear;
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function createPosition(ICErc20 _collateralMarket, ICErc20 _stableMarket) public returns (LeveredPosition) {
    if (!borrowableMarketsByCollateral[_collateralMarket].contains(address(_stableMarket))) revert PairNotWhitelisted();

    LeveredPosition position = new LeveredPosition(msg.sender, _collateralMarket, _stableMarket);

    accountsWithOpenPositions.add(msg.sender);
    positionsByAccount[msg.sender].add(address(position));

    return position;
  }

  function createAndFundPosition(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    IERC20Upgradeable _fundingAsset,
    uint256 _fundingAmount
  ) public returns (LeveredPosition) {
    LeveredPosition position = createPosition(_collateralMarket, _stableMarket);
    _fundingAsset.safeTransferFrom(msg.sender, address(this), _fundingAmount);
    _fundingAsset.approve(address(position), _fundingAmount);
    position.fundPosition(_fundingAsset, _fundingAmount);
    return position;
  }

  function createAndFundPositionAtRatio(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    IERC20Upgradeable _fundingAsset,
    uint256 _fundingAmount,
    uint256 _leverageRatio
  ) public returns (LeveredPosition) {
    LeveredPosition position = createPosition(_collateralMarket, _stableMarket);
    _fundingAsset.safeTransferFrom(msg.sender, address(this), _fundingAmount);
    _fundingAsset.approve(address(position), _fundingAmount);
    position.fundPosition(_fundingAsset, _fundingAmount);

    position.adjustLeverageRatio(_leverageRatio);

    return position;
  }

  // @return true if removed, otherwise false
  function removeClosedPosition(address closedPosition) public returns (bool removed) {
    EnumerableSet.AddressSet storage userPositions = positionsByAccount[msg.sender];
    if (!userPositions.contains(closedPosition)) revert NoSuchPosition();
    if (!LeveredPosition(closedPosition).isPositionClosed()) revert PositionNotClosed();

    removed = userPositions.remove(closedPosition);
    if (userPositions.length() == 0) accountsWithOpenPositions.remove(msg.sender);
  }

  /*----------------------------------------------------------------
                            View Functions
  ----------------------------------------------------------------*/

  function getPositionsByAccount(address account) public view returns (address[] memory) {
    return positionsByAccount[account].values();
  }

  function getAccountsWithOpenPositions() public view returns (address[] memory) {
    return accountsWithOpenPositions.values();
  }

  function getWhitelistedCollateralMarkets() public view returns (address[] memory) {
    return collateralMarkets.values();
  }

  // @dev returns lists of the market addresses, names and symbols of the underlying assets of those collateral markets that are whitelisted
  function getCollateralMarkets()
    public
    view
    returns (
      address[] memory markets,
      address[] memory poolOfMarket,
      address[] memory underlyings,
      string[] memory names,
      string[] memory symbols,
      uint8[] memory decimals,
      uint256[] memory totalUnderlyingSupplied,
      uint256[] memory ratesPerBlock
    )
  {
    markets = collateralMarkets.values();
    poolOfMarket = new address[](markets.length);
    underlyings = new address[](markets.length);
    names = new string[](markets.length);
    symbols = new string[](markets.length);
    totalUnderlyingSupplied = new uint256[](markets.length);
    decimals = new uint8[](markets.length);
    ratesPerBlock = new uint256[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(markets[i]);
      poolOfMarket[i] = market.comptroller();
      address underlyingAddress = market.underlying();
      underlyings[i] = underlyingAddress;
      ERC20Upgradeable underlying = ERC20Upgradeable(underlyingAddress);
      names[i] = underlying.name();
      symbols[i] = underlying.symbol();
      decimals[i] = underlying.decimals();
      totalUnderlyingSupplied[i] = market.getTotalUnderlyingSupplied();
      ratesPerBlock[i] = market.supplyRatePerBlock();
    }
  }

  function getBorrowableMarketsByCollateral(ICErc20 _collateralMarket) public view returns (address[] memory) {
    return borrowableMarketsByCollateral[_collateralMarket].values();
  }

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) public view returns (bool) {
    return liquidatorsRegistry.isRedemptionPathSupported(inputToken, outputToken);
  }

  function getSlippage(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (uint256 slippage)
  {
    slippage = conversionSlippage[inputToken][outputToken];
    if (slippage == 0) return MAX_SLIPPAGE;
  }

  function getMinBorrowNative() external view returns (uint256) {
    return fuseFeeDistributor.minBorrowEth();
  }

  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData)
  {
    return liquidatorsRegistry.getRedemptionStrategies(inputToken, outputToken);
  }

  // @dev returns the Rate for the chosen borrowable at the specified  leverage ratio and supply amount
  function getBorrowRateAtRatio(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    uint256 _baseCollateral,
    uint256 _targetLeverageRatio
  ) public view returns (uint256) {
    IComptroller pool = IComptroller(_stableMarket.comptroller());
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(_stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(_collateralMarket);

    uint256 borrowAmount = ((_targetLeverageRatio - 1e18) * _baseCollateral * collateralAssetPrice) /
      (stableAssetPrice * 1e18);
    return _stableMarket.borrowRatePerBlockAfterBorrow(borrowAmount);
  }

  // @dev returns lists of the market addresses, names, symbols and the current Rate for each Borrowable asset
  function getBorrowableMarketsAndRates(ICErc20 _collateralMarket)
    external
    view
    returns (
      address[] memory markets,
      address[] memory underlyings,
      string[] memory names,
      string[] memory symbols,
      uint256[] memory rates,
      uint8[] memory decimals
    )
  {
    markets = borrowableMarketsByCollateral[_collateralMarket].values();
    underlyings = new address[](markets.length);
    names = new string[](markets.length);
    symbols = new string[](markets.length);
    rates = new uint256[](markets.length);
    decimals = new uint8[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(markets[i]);
      address underlyingAddress = market.underlying();
      underlyings[i] = underlyingAddress;
      ERC20Upgradeable underlying = ERC20Upgradeable(underlyingAddress);
      names[i] = underlying.name();
      symbols[i] = underlying.symbol();
      rates[i] = market.borrowRatePerBlock();
      decimals[i] = underlying.decimals();
    }
  }

  function getNetAPYPerBlock(
    uint256 _supplyAPY,
    uint256 _supplyAmount,
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    uint256 _targetLeverageRatio
  ) external view returns (int256) {
    IComptroller pool = IComptroller(_stableMarket.comptroller());
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(_stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(_collateralMarket);

    uint256 supplyValueScaled = _supplyAmount * stableAssetPrice;
    uint256 yieldFromSupplyScaled = _supplyAPY * _supplyAmount;
    int256 yieldValueScaled = int256((yieldFromSupplyScaled * collateralAssetPrice) / 1e18);
    uint256 borrowedValueScaled = ((_targetLeverageRatio - 1e18) * supplyValueScaled) / 1e18;
    uint256 _borrowRate = _stableMarket.borrowRatePerBlock() * blocksPerYear;
    int256 borrowInterestValueScaled = int256((_borrowRate * borrowedValueScaled) / 1e18);

    int256 netValueDiffScaled = yieldValueScaled - borrowInterestValueScaled;

    int256 netAPY = ((netValueDiffScaled / collateralAssetPrice) * 1e18) / _supplyAmount;
    return netAPY / blocksPerYear;
  }

  /*----------------------------------------------------------------
                            Admin Functions
  ----------------------------------------------------------------*/

  function _setPairWhitelisted(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    bool _whitelisted
  ) public onlyOwner {
    require(_collateralMarket.comptroller() == _stableMarket.comptroller(), "markets not of the same pool");

    if (_whitelisted) {
      collateralMarkets.add(address(_collateralMarket));
      borrowableMarketsByCollateral[_collateralMarket].add(address(_stableMarket));
    } else {
      borrowableMarketsByCollateral[_collateralMarket].remove(address(_stableMarket));
      if (borrowableMarketsByCollateral[_collateralMarket].length() == 0)
        collateralMarkets.remove(address(_collateralMarket));
    }
  }

  function _setLiquidatorsRegistry(ILiquidatorsRegistry _liquidatorsRegistry) external onlyOwner {
    liquidatorsRegistry = _liquidatorsRegistry;
  }

  function _setSlippages(
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens,
    uint256[] calldata slippages
  ) external onlyOwner {
    require(slippages.length == inputTokens.length && inputTokens.length == outputTokens.length, "!arrays len");

    for (uint256 i = 0; i < slippages.length; i++) {
      conversionSlippage[inputTokens[i]][outputTokens[i]] = slippages[i];
    }
  }
}
