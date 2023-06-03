// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../midas/DiamondExtension.sol";
import { LeveredPositionFactoryStorage } from "./LeveredPositionFactoryStorage.sol";
import { ILeveredPositionFactoryExtension } from "./ILeveredPositionFactory.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { LeveredPosition } from "./LeveredPosition.sol";
import { IComptroller, IPriceOracle } from "../../external/compound/IComptroller.sol";
import { ILiquidatorsRegistry } from "../../liquidators/registry/ILiquidatorsRegistry.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LeveredPositionFactoryExtension is LeveredPositionFactoryStorage, DiamondExtension, ILeveredPositionFactoryExtension {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using EnumerableSet for EnumerableSet.AddressSet;

  error PairNotWhitelisted();
  error NoSuchPosition();
  error PositionNotClosed();

  // @notice maximum slippage in swaps, in bps
  uint256 public constant MAX_SLIPPAGE = 900; // 9%

  function _getExtensionFunctions() external pure override returns (bytes4[] memory) {
    uint8 fnsCount = 16;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.getRedemptionStrategies.selector;
    functionSelectors[--fnsCount] = this.getMinBorrowNative.selector;
    functionSelectors[--fnsCount] = this.createPosition.selector;
    functionSelectors[--fnsCount] = this.createAndFundPosition.selector;
    functionSelectors[--fnsCount] = this.createAndFundPositionAtRatio.selector;
    functionSelectors[--fnsCount] = this.removeClosedPosition.selector;
    functionSelectors[--fnsCount] = this.isFundingAllowed.selector;
    functionSelectors[--fnsCount] = this.getSlippage.selector;
    functionSelectors[--fnsCount] = this.getNetAPY.selector;
    functionSelectors[--fnsCount] = this.getBorrowableMarketsAndRates.selector;
    functionSelectors[--fnsCount] = this.getBorrowRateAtRatio.selector;
    functionSelectors[--fnsCount] = this.getBorrowableMarketsByCollateral.selector;
    functionSelectors[--fnsCount] = this.getCollateralMarkets.selector;
    functionSelectors[--fnsCount] = this.getWhitelistedCollateralMarkets.selector;
    functionSelectors[--fnsCount] = this.getAccountsWithOpenPositions.selector;
    functionSelectors[--fnsCount] = this.getPositionsByAccount.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
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
  ) external returns (LeveredPosition) {
    LeveredPosition position = createAndFundPosition(_collateralMarket, _stableMarket, _fundingAsset, _fundingAmount);
    position.adjustLeverageRatio(_leverageRatio);
    return position;
  }

  // @return true if removed, otherwise false
  function removeClosedPosition(address closedPosition) external returns (bool removed) {
    EnumerableSet.AddressSet storage userPositions = positionsByAccount[msg.sender];
    if (!userPositions.contains(closedPosition)) revert NoSuchPosition();
    if (!LeveredPosition(closedPosition).isPositionClosed()) revert PositionNotClosed();

    removed = userPositions.remove(closedPosition);
    if (userPositions.length() == 0) accountsWithOpenPositions.remove(msg.sender);
  }

  /*----------------------------------------------------------------
                            View Functions
  ----------------------------------------------------------------*/

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external view returns (bool) {
    return liquidatorsRegistry.isRedemptionPathSupported(inputToken, outputToken);
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

  function getSlippage(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
  external
  view
  returns (uint256 slippage)
  {
    slippage = conversionSlippage[inputToken][outputToken];
    if (slippage == 0) return MAX_SLIPPAGE;
  }

  function getPositionsByAccount(address account) external view returns (address[] memory) {
    return positionsByAccount[account].values();
  }

  function getAccountsWithOpenPositions() external view returns (address[] memory) {
    return accountsWithOpenPositions.values();
  }

  function getWhitelistedCollateralMarkets() external view returns (address[] memory) {
    return collateralMarkets.values();
  }

  // @dev returns lists of the market addresses, names and symbols of the underlying assets of those collateral markets that are whitelisted
  function getCollateralMarkets()
  external
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

  function getBorrowableMarketsByCollateral(ICErc20 _collateralMarket) external view returns (address[] memory) {
    return borrowableMarketsByCollateral[_collateralMarket].values();
  }

  // @dev returns the Rate for the chosen borrowable at the specified  leverage ratio and supply amount
  function getBorrowRateAtRatio(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    uint256 _baseCollateral,
    uint256 _targetLeverageRatio
  ) external view returns (uint256) {
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

  /// @notice this is a lens fn, it is not intended to be used on-chain
  function getNetAPY(
    uint256 _supplyAPY,
    uint256 _supplyAmount,
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    uint256 _targetLeverageRatio
  ) external view returns (int256 netAPY) {
    IComptroller pool = IComptroller(_collateralMarket.comptroller());
    IPriceOracle oracle = pool.oracle();
    // TODO the calcs can be implemented without using collateralAssetPrice
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(_collateralMarket);

    // total collateral = base collateral + levered collateral
    uint256 totalCollateral = (_supplyAmount * _targetLeverageRatio) / 1e18;
    uint256 yieldFromTotalSupplyScaled = _supplyAPY * totalCollateral;
    int256 yieldValueScaled = int256((yieldFromTotalSupplyScaled * collateralAssetPrice) / 1e18);

    uint256 borrowedValueScaled = (totalCollateral - _supplyAmount) * collateralAssetPrice;
    uint256 _borrowRate = _stableMarket.borrowRatePerBlock() * blocksPerYear;
    int256 borrowInterestValueScaled = int256((_borrowRate * borrowedValueScaled) / 1e18);

    int256 netValueDiffScaled = yieldValueScaled - borrowInterestValueScaled;

    netAPY = ((netValueDiffScaled / int256(collateralAssetPrice)) * 1e18) / int256(_supplyAmount);
  }
}