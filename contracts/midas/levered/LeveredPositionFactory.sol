// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./ILeveredPositionFactory.sol";
import "./LeveredPosition.sol";
import "../SafeOwnableUpgradeable.sol";
import "../../compound/IFuseFeeDistributor.sol";

import "../../liquidators/registry/ILiquidatorsRegistry.sol";
import "../../liquidators/SolidlySwapLiquidator.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LeveredPositionFactory is ILeveredPositionFactory, SafeOwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using EnumerableSet for EnumerableSet.AddressSet;

  IFuseFeeDistributor public ffd;
  ILiquidatorsRegistry public liquidatorsRegistry;
  uint256 public blocksPerYear;

  mapping(address => EnumerableSet.AddressSet) private positionsByAccount;
  EnumerableSet.AddressSet private collateralMarkets;
  mapping(ICErc20 => EnumerableSet.AddressSet) private borrowableMarketsByCollateral;

  /*----------------------------------------------------------------
                        Initializer Functions
  ----------------------------------------------------------------*/

  constructor() {
    _disableInitializers();
  }

  function initialize(
    IFuseFeeDistributor _ffd,
    ILiquidatorsRegistry _registry,
    uint256 _blocksPerYear
  ) public initializer {
    __SafeOwnable_init(msg.sender);
    ffd = _ffd;
    liquidatorsRegistry = _registry;
    blocksPerYear = _blocksPerYear;
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function createPosition(ICErc20 _collateralMarket, ICErc20 _stableMarket) public returns (LeveredPosition) {
    require(borrowableMarketsByCollateral[_collateralMarket].contains(address(_stableMarket)), "!pair not whitelisted");

    LeveredPosition position = new LeveredPosition(msg.sender, _collateralMarket, _stableMarket);
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

  // @return true if removed, otherwise false
  function removeClosedPosition(address closedPosition) public returns (bool) {
    EnumerableSet.AddressSet storage userPositions = positionsByAccount[msg.sender];
    require(userPositions.contains(closedPosition), "!no such position");
    require(LeveredPosition(closedPosition).isPositionClosed(), "!not closed");

    return userPositions.remove(closedPosition);
  }

  /*----------------------------------------------------------------
                            View Functions
  ----------------------------------------------------------------*/

  function getPositionsByAccount(address account) public view returns (address[] memory) {
    return positionsByAccount[account].values();
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
      address[] memory underlyings,
      string[] memory names,
      string[] memory symbols,
      uint256[] memory rates
    )
  {
    markets = collateralMarkets.values();
    underlyings = new address[](markets.length);
    names = new string[](markets.length);
    symbols = new string[](markets.length);
    rates = new uint256[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(markets[i]);
      address underlyingAddress = market.underlying();
      ERC20Upgradeable underlying = ERC20Upgradeable(underlyingAddress);
      names[i] = underlying.name();
      symbols[i] = underlying.symbol();
      underlyings[i] = underlyingAddress;
      rates[i] = market.supplyRatePerBlock() * blocksPerYear;
    }
  }

  function getBorrowableMarketsByCollateral(ICErc20 _collateralMarket) public view returns (address[] memory) {
    return borrowableMarketsByCollateral[_collateralMarket].values();
  }

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) public view returns (bool) {
    return liquidatorsRegistry.hasRedemptionStrategyForTokens(inputToken, outputToken);
  }

  function getMinBorrowNative() external view returns (uint256) {
    return ffd.minBorrowEth();
  }

  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData)
  {
    return liquidatorsRegistry.getRedemptionStrategies(inputToken, outputToken);
  }

  function hasRedemptionStrategyForTokens(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (bool)
  {
    return liquidatorsRegistry.hasRedemptionStrategyForTokens(inputToken, outputToken);
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
    return _stableMarket.borrowRatePerBlockAfterBorrow(borrowAmount) * blocksPerYear;
  }

  function getBorrowRates(address[] memory _markets) public view returns (uint256[] memory rates) {
    rates = new uint256[](_markets.length);
    for (uint256 i = 0; i < _markets.length; i++) {
      rates[i] = ICErc20(_markets[i]).borrowRatePerBlock() * blocksPerYear;
    }
  }

  // @dev returns lists of the market addresses, names, symbols and the current Rate for each Borrowable asset
  function getBorrowableMarketsAndRates(ICErc20 _collateralMarket)
    public
    view
    returns (
      address[] memory markets,
      address[] memory underlyings,
      string[] memory names,
      string[] memory symbols,
      uint256[] memory rates
    )
  {
    markets = borrowableMarketsByCollateral[_collateralMarket].values();
    underlyings = new address[](markets.length);
    names = new string[](markets.length);
    symbols = new string[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      address underlyingAddress = ICErc20(markets[i]).underlying();
      ERC20Upgradeable underlying = ERC20Upgradeable(underlyingAddress);
      names[i] = underlying.name();
      symbols[i] = underlying.symbol();
      underlyings[i] = underlyingAddress;
    }
    rates = getBorrowRates(markets);
  }

  /*----------------------------------------------------------------
                            Admin Functions
  ----------------------------------------------------------------*/

  function _setPairWhitelisted(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    bool _whitelisted
  ) public onlyOwner {
    if (_whitelisted) {
      collateralMarkets.add(address(_collateralMarket));
      borrowableMarketsByCollateral[_collateralMarket].add(address(_stableMarket));
    } else {
      borrowableMarketsByCollateral[_collateralMarket].remove(address(_stableMarket));
      if (borrowableMarketsByCollateral[_collateralMarket].length() == 0)
        collateralMarkets.remove(address(_collateralMarket));
    }
  }

  function setLiquidatorsRegistry(ILiquidatorsRegistry _liquidatorsRegistry) external onlyOwner {
    liquidatorsRegistry = _liquidatorsRegistry;
  }
}
